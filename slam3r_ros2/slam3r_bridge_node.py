#!/usr/bin/env python3
"""
slam3r_bridge_node.py
─────────────────────
ROS2 node that subscribes to /hm30/image_raw, feeds decoded frames into
SLAM3R's online reconstruction pipeline, and publishes the accumulated
point cloud as sensor_msgs/PointCloud2 on /hm30/pointcloud.

Architecture:
  /hm30/image_raw (sensor_msgs/Image)
        │
        ▼
  Frame queue  ──►  SLAM3R worker thread  ──►  /hm30/pointcloud (PointCloud2)

Usage:
  # Activate the slam3r conda environment first, then:
  source /opt/ros/humble/setup.bash
  python3 slam3r_bridge_node.py

  # Override defaults via ROS2 parameters:
  python3 slam3r_bridge_node.py --ros-args \\
      -p input_topic:=/hm30/image_raw \\
      -p output_topic:=/hm30/pointcloud \\
      -p frame_skip:=2 \\
      -p publish_every_n_frames:=5 \\
      -p conf_threshold:=1.5 \\
      -p initial_winsize:=5
"""

import sys
import os
import threading
import queue
import argparse
import time
import struct

import numpy as np
import cv2

# ── ROS2 ──────────────────────────────────────────────────────────────────────
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Image, PointCloud2, PointField
from std_msgs.msg import Header
from builtin_interfaces.msg import Time as RosTime
from geometry_msgs.msg import TransformStamped
import tf2_ros
import sqlite3
import os

# ── SLAM3R ────────────────────────────────────────────────────────────────────
# SLAM3R_PATH must be set before import (done by the runner script).
_slam3r_path = os.environ.get("SLAM3R_PATH", "")
if _slam3r_path and _slam3r_path not in sys.path:
    sys.path.insert(0, _slam3r_path)

try:
    import torch
    from slam3r.models import Image2PointsModel, Local2WorldModel, inf
    from slam3r.utils.device import to_numpy
    from slam3r.pipeline.recon_online_pipeline import (
        get_raw_input_frame,
        process_input_frame,
        initialize_scene,
        initial_scene_for_accumulated_frames,
        recover_points_in_initial_window,
        register_initial_window_frames,
        select_ids_as_reference,
        pointmap_local_recon,
        pointmap_global_register,
        update_buffer_set,
    )
    _SLAM3R_AVAILABLE = True
except ImportError as e:
    print(f"[WARN] SLAM3R not importable: {e}")
    print("[WARN] Running in DRY-RUN mode — frames consumed but no reconstruction.")
    _SLAM3R_AVAILABLE = False


# ══════════════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════════════

def ros_image_to_bgr(msg: Image) -> np.ndarray:
    """Convert a sensor_msgs/Image (rgb8) to an OpenCV BGR numpy array."""
    data = np.frombuffer(msg.data, dtype=np.uint8)
    if msg.encoding in ("rgb8", "RGB8"):
        img = data.reshape((msg.height, msg.width, 3))
        return cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
    elif msg.encoding in ("bgr8", "BGR8"):
        return data.reshape((msg.height, msg.width, 3)).copy()
    elif msg.encoding in ("mono8",):
        gray = data.reshape((msg.height, msg.width))
        return cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
    else:
        raise ValueError(f"Unsupported encoding: {msg.encoding}")


def make_pointcloud2(points_xyz: np.ndarray,
                     colors_rgb: np.ndarray,
                     frame_id: str,
                     stamp) -> PointCloud2:
    """
    Build a sensor_msgs/PointCloud2 (XYZRGB) from numpy arrays.

    Args:
        points_xyz : (N, 3) float32
        colors_rgb : (N, 3) uint8  in [0, 255]
        frame_id   : TF frame string
        stamp      : rclpy time (node.get_clock().now().to_msg())
    """
    assert len(points_xyz) == len(colors_rgb)
    N = len(points_xyz)

    # Pack RGB into a float32 (standard ROS XYZRGB convention)
    r = colors_rgb[:, 0].astype(np.uint32)
    g = colors_rgb[:, 1].astype(np.uint32)
    b = colors_rgb[:, 2].astype(np.uint32)
    rgb_packed = ((r << 16) | (g << 8) | b).astype(np.uint32)
    rgb_float = rgb_packed.view(np.float32)

    # Interleave [x, y, z, rgb] → each point = 16 bytes
    data = np.zeros(N, dtype=[
        ('x', np.float32),
        ('y', np.float32),
        ('z', np.float32),
        ('rgb', np.float32),
    ])
    data['x']   = points_xyz[:, 0].astype(np.float32)
    data['y']   = points_xyz[:, 1].astype(np.float32)
    data['z']   = points_xyz[:, 2].astype(np.float32)
    data['rgb'] = rgb_float

    fields = [
        PointField(name='x',   offset=0,  datatype=PointField.FLOAT32, count=1),
        PointField(name='y',   offset=4,  datatype=PointField.FLOAT32, count=1),
        PointField(name='z',   offset=8,  datatype=PointField.FLOAT32, count=1),
        PointField(name='rgb', offset=12, datatype=PointField.FLOAT32, count=1),
    ]

    msg = PointCloud2()
    msg.header.frame_id = frame_id
    msg.header.stamp    = stamp
    msg.height          = 1
    msg.width           = N
    msg.fields          = fields
    msg.is_bigendian    = False
    msg.point_step      = 16
    msg.row_step        = 16 * N
    msg.data            = data.tobytes()
    msg.is_dense        = False
    return msg


# ══════════════════════════════════════════════════════════════════════════════
# Fake args namespace (mirrors recon.py argparse defaults)
# ══════════════════════════════════════════════════════════════════════════════

def _make_args(device, conf_thres_i2p, conf_thres_l2w,
               keyframe_stride, initial_winsize, win_r,
               num_scene_frame, buffer_size, retrieve_freq,
               min_publish_conf=20.0):
    args = argparse.Namespace()
    args.device           = device
    args.conf_thres_i2p   = conf_thres_i2p
    args.conf_thres_l2w   = conf_thres_l2w
    args.keyframe_stride  = keyframe_stride
    args.initial_winsize  = initial_winsize
    args.win_r            = win_r
    args.num_scene_frame  = num_scene_frame
    args.max_num_register = 10
    args.num_points_save  = 2_000_000
    args.norm_input       = False
    args.save_frequency   = 3
    args.save_each_frame  = False
    args.retrieve_freq    = retrieve_freq
    args.update_buffer_intv = 1
    args.buffer_size      = buffer_size
    args.buffer_strategy  = 'reservoir'
    args.perframe         = 1
    args.test_name        = "ros2_live"
    args.save_preds       = False
    args.save_for_eval    = False
    args.save_online      = False
    args.min_publish_conf = min_publish_conf  # skip publish if frame conf < this
    return args


# ══════════════════════════════════════════════════════════════════════════════
# SLAM3R worker
# ══════════════════════════════════════════════════════════════════════════════

class SLAM3RWorker:
    """
    Runs SLAM3R online reconstruction in a background thread.
    Accepts BGR frames via `push_frame()`.
    Accumulated global point cloud is retrieved via `get_pointcloud()`.
    """

    def __init__(self, device: str, args: argparse.Namespace,
                 on_pointcloud_ready, logger):
        self._device   = device
        self._args     = args
        self._callback = on_pointcloud_ready
        self._log      = logger

        self._frame_queue: queue.Queue = queue.Queue(maxsize=30)
        self._stop_event  = threading.Event()
        self._thread      = threading.Thread(target=self._run, daemon=True)

        # Shared global point cloud (protected by lock)
        self._pcd_lock  = threading.Lock()
        self._pts_xyz   = np.empty((0, 3), dtype=np.float32)
        self._pts_rgb   = np.empty((0, 3), dtype=np.uint8)

    def start(self):
        self._thread.start()

    def stop(self):
        self._stop_event.set()
        # Unblock the worker if it's waiting for a frame
        try:
            self._frame_queue.put_nowait(None)
        except queue.Full:
            pass
        self._thread.join(timeout=10)

    def push_frame(self, bgr: np.ndarray):
        """Non-blocking push. Drops oldest frame if queue is full."""
        try:
            self._frame_queue.put_nowait(bgr)
        except queue.Full:
            try:
                self._frame_queue.get_nowait()  # drop oldest
                self._frame_queue.put_nowait(bgr)
            except queue.Empty:
                pass

    def get_pointcloud(self):
        """Thread-safe snapshot of the current global point cloud."""
        with self._pcd_lock:
            return self._pts_xyz.copy(), self._pts_rgb.copy()

    # ── Internal reconstruction loop ─────────────────────────────────────────

    def _run(self):
        try:
            self._run_inner()
        except Exception as exc:
            import traceback
            print(f"[SLAM3R WORKER FATAL] {exc}")
            traceback.print_exc()

    def _run_inner(self):
        print("[SLAM3R] Setting up SQLite persistence at data/slam3r_map.db", flush=True)
        os.makedirs("data", exist_ok=True)
        self._db_conn = sqlite3.connect("data/slam3r_map.db", check_same_thread=False)
        self._db_conn.execute("DROP TABLE IF EXISTS map_chunks")
        self._db_conn.execute("CREATE TABLE map_chunks (frame_id INTEGER PRIMARY KEY, xyz_blob BLOB, rgb_blob BLOB)")
        self._db_conn.commit()

        print("[SLAM3R] Loading models from HuggingFace (first run downloads weights)…", flush=True)
        i2p_model = Image2PointsModel.from_pretrained('siyan824/slam3r_i2p').to(self._device).eval()
        l2w_model = Local2WorldModel.from_pretrained('siyan824/slam3r_l2w').to(self._device).eval()
        print("[SLAM3R] Models loaded. Waiting for frames…", flush=True)

        args       = self._args
        kf_stride  = args.keyframe_stride
        init_winsize = args.initial_winsize

        # State mirrors scene_recon_pipeline_online
        data_views            = []
        rgb_imgs              = []
        input_views           = []
        per_frame_res         = dict(i2p_pcds=[], i2p_confs=[], l2w_pcds=[], l2w_confs=[])
        registered_confs_mean = []
        local_confs_mean      = []
        last_ref_ids_buffer   = []
        fail_view             = {}
        buffering_set_ids     = []
        milestone             = 0
        candi_frame_id        = 0
        init_ref_id           = 0
        init_num              = 0
        initialized           = False
        num_frame_read        = 0

        class _FakeFrameReader:
            """Adapter so we can reuse get_raw_input_frame with a BGR numpy array."""
            type = "video"

        fake_reader = _FakeFrameReader()

        while not self._stop_event.is_set():
            try:
                bgr = self._frame_queue.get(timeout=0.5)
            except queue.Empty:
                continue
            if bgr is None:
                break   # stop signal

            current_frame_id = num_frame_read
            num_frame_read  += 1

            # get_raw_input_frame expects a raw OpenCV frame when type=="video"
            frame, data_views, rgb_imgs = get_raw_input_frame(
                fake_reader.type, data_views, rgb_imgs,
                current_frame_id, bgr, self._device
            )
            input_view, per_frame_res, registered_confs_mean = process_input_frame(
                per_frame_res, registered_confs_mean,
                data_views, current_frame_id, i2p_model
            )
            input_views.append(input_view)

            # ── Wait for enough frames to initialize ──────────────────────────
            if current_frame_id < (init_winsize - 1) * kf_stride:
                if current_frame_id == 0 or (current_frame_id+1) % 5 == 0:
                    print(f"[SLAM3R] Buffering frame {current_frame_id+1}"
                          f" / {(init_winsize-1)*kf_stride+1} for init…", flush=True)
                continue

            # ── Scene initialization ──────────────────────────────────────────
            if not initialized and current_frame_id == (init_winsize - 1) * kf_stride:
                print("[SLAM3R] Initializing scene…", flush=True)
                out = initial_scene_for_accumulated_frames(
                    input_views, init_winsize, kf_stride, i2p_model,
                    per_frame_res, registered_confs_mean,
                    args.buffer_size, args.conf_thres_i2p
                )
                buffering_set_ids     = out[0]
                init_ref_id           = out[1]
                init_num              = out[2]
                input_views           = out[3]
                per_frame_res         = out[4]
                registered_confs_mean = out[5]

                local_confs_mean, per_frame_res, input_views = recover_points_in_initial_window(
                    current_frame_id, buffering_set_ids, kf_stride,
                    init_ref_id, per_frame_res, input_views, i2p_model,
                    args.conf_thres_i2p
                )
                if kf_stride > 1:
                    _, input_views, per_frame_res = register_initial_window_frames(
                        init_num, kf_stride, buffering_set_ids, input_views,
                        l2w_model, per_frame_res, registered_confs_mean,
                        self._device, args.norm_input
                    )
                milestone      = init_num * kf_stride + 1
                candi_frame_id = len(buffering_set_ids)
                initialized    = True
                print("[SLAM3R] Scene initialized — starting incremental reconstruction.", flush=True)
                self._publish_current_cloud(input_views, rgb_imgs, per_frame_res,
                                            args.conf_thres_i2p, registered_confs_mean,
                                            current_frame_id)
                continue

            # ── Incremental reconstruction ────────────────────────────────────
            if not initialized:
                continue

            ref_ids, ref_ids_buffer = select_ids_as_reference(
                buffering_set_ids, current_frame_id, input_views,
                i2p_model, args.num_scene_frame, args.win_r,
                kf_stride, args.retrieve_freq, last_ref_ids_buffer
            )
            last_ref_ids_buffer = ref_ids_buffer

            local_views = [input_views[current_frame_id]] + [input_views[i] for i in ref_ids]
            local_confs_mean, per_frame_res, input_views = pointmap_local_recon(
                local_views, i2p_model, current_frame_id, 0,
                per_frame_res, input_views, args.conf_thres_i2p, local_confs_mean
            )

            ref_views = [input_views[i] for i in ref_ids]
            input_views, per_frame_res, registered_confs_mean = pointmap_global_register(
                ref_views, input_views, l2w_model, per_frame_res,
                registered_confs_mean, current_frame_id,
                device=self._device, norm_input=args.norm_input
            )

            next_frame_id = current_frame_id + 1
            update_intv   = kf_stride * args.update_buffer_intv
            if next_frame_id - milestone >= update_intv:
                milestone, candi_frame_id, buffering_set_ids = update_buffer_set(
                    next_frame_id, args.buffer_size, kf_stride,
                    buffering_set_ids, args.buffer_strategy,
                    registered_confs_mean, local_confs_mean,
                    candi_frame_id, milestone
                )

            conf = registered_confs_mean[current_frame_id]
            conf_val = conf.item() if hasattr(conf, 'item') else float(conf)
            if conf_val < 10:
                fail_view[current_frame_id] = conf_val

            print(f"[SLAM3R] Frame {current_frame_id} done, conf={conf_val:.2f}", flush=True)

            # Skip publish if this frame is poorly registered (avoids adding a ghost layer)
            if conf_val < args.min_publish_conf:
                print(f"[SLAM3R] Skipping publish (conf {conf_val:.1f} < {args.min_publish_conf})", flush=True)
                continue

            self._publish_current_cloud(input_views, rgb_imgs, per_frame_res,
                                        args.conf_thres_i2p, registered_confs_mean,
                                        current_frame_id)

        print("[SLAM3R] Worker thread exiting.", flush=True)

    def _publish_current_cloud(self, input_views, rgb_imgs, per_frame_res,
                                conf_thres, registered_confs_mean, up_to_frame):
        """
        Collect point clouds from well-registered frames and pass to callback.

        Only includes frames from a recent sliding window to prevent long-term
        drift buildup. Frames with poor global registration (low mean L2W conf)
        are skipped entirely to avoid ghost layers.
        """
        try:
            # 1. Update DB with recent frames from the sliding window
            # SLAM3R does global bundle adjustment on recent frames, so we
            # re-insert them to update their poses in the DB.
            WINDOW_SIZE = 20
            frame_indices = list(range(len(input_views)))
            frame_indices = frame_indices[-WINDOW_SIZE:]

            FRAME_CONF_MIN = 35.0

            for i in frame_indices:
                view = input_views[i]
                if 'pts3d_world' not in view:
                    continue

                # Skip the entire frame if its global registration was poor
                if i < len(registered_confs_mean):
                    frame_conf = registered_confs_mean[i]
                    frame_conf_val = frame_conf.item() if hasattr(frame_conf, 'item') else float(frame_conf)
                    if frame_conf_val < FRAME_CONF_MIN:
                        continue

                pcd = to_numpy(view['pts3d_world'][0])          # (224, 224, 3)
                if pcd.shape[0] == 3:
                    pcd = pcd.transpose(1, 2, 0)
                pcd = pcd.reshape(-1, 3).astype(np.float32)

                # Corresponding RGB image
                if i < len(rgb_imgs):
                    rgb = rgb_imgs[i].reshape(-1, 3)
                    # rgb_imgs stores BGR — convert to RGB for the message
                    rgb = rgb[:, ::-1].copy()
                else:
                    rgb = np.ones((pcd.shape[0], 3), dtype=np.uint8) * 128

                # Per-pixel confidence filter (remove low-confidence pixels)
                if (per_frame_res['l2w_confs'] is not None
                        and i < len(per_frame_res['l2w_confs'])
                        and per_frame_res['l2w_confs'][i] is not None):
                    conf_map = per_frame_res['l2w_confs'][i]
                    if hasattr(conf_map, 'cpu'):
                        conf_map = conf_map.cpu().numpy()
                    mask = conf_map.reshape(-1) > conf_thres
                    pcd  = pcd[mask]
                    rgb  = rgb[mask]

                if len(pcd):
                    # Save to DB (ensure contiguous layout and strict types to prevent frombuffer scrambling)
                    xyz_bytes = np.ascontiguousarray(pcd, dtype=np.float32).tobytes()
                    rgb_bytes = np.ascontiguousarray(rgb, dtype=np.uint8).tobytes()
                    self._db_conn.execute(
                        "INSERT OR REPLACE INTO map_chunks (frame_id, xyz_blob, rgb_blob) VALUES (?, ?, ?)",
                        (i, xyz_bytes, rgb_bytes)
                    )
            
            self._db_conn.commit()

            # 2. Read the entire map from DB to publish
            cursor = self._db_conn.execute("SELECT xyz_blob, rgb_blob FROM map_chunks")
            db_pcds = []
            db_rgbs = []
            for row in cursor:
                db_pcd = np.frombuffer(row[0], dtype=np.float32).reshape(-1, 3)
                db_rgb = np.frombuffer(row[1], dtype=np.uint8).reshape(-1, 3)
                db_pcds.append(db_pcd)
                db_rgbs.append(db_rgb)

            if not db_pcds:
                return

            all_pts = np.concatenate(db_pcds, axis=0)
            all_rgb = np.concatenate(db_rgbs, axis=0)

            # ── Coordinate frame conversion ────────────────────────────────────
            # SLAM3R outputs in OpenCV/camera convention:
            #   X = right, Y = down, Z = forward (depth)
            # ROS REP-103 convention:
            #   X = forward, Y = left, Z = up
            # Transform: x_ros = z_slam, y_ros = -x_slam, z_ros = -y_slam
            ros_pts = np.empty_like(all_pts)
            ros_pts[:, 0] =  all_pts[:, 2]   # depth  → forward (X)
            ros_pts[:, 1] = -all_pts[:, 0]   # right  → -left  (Y)
            ros_pts[:, 2] = -all_pts[:, 1]   # down   → -up    (Z)
            all_pts = ros_pts

            # Down-sample if the cloud is massive (keep ≤ 500k points for ROS2)
            MAX_PTS = 500_000
            if len(all_pts) > MAX_PTS:
                idx     = np.random.choice(len(all_pts), MAX_PTS, replace=False)
                all_pts = all_pts[idx]
                all_rgb = all_rgb[idx]

            with self._pcd_lock:
                self._pts_xyz = all_pts
                self._pts_rgb = all_rgb.astype(np.uint8)

            self._callback(all_pts, all_rgb.astype(np.uint8))
        except Exception as exc:
            print(f"[SLAM3R] Point cloud assembly error: {exc}", flush=True)


# ══════════════════════════════════════════════════════════════════════════════
# ROS2 Node
# ══════════════════════════════════════════════════════════════════════════════

class SLAM3RBridgeNode(Node):

    def __init__(self):
        super().__init__('slam3r_bridge')

        # ── Parameters ───────────────────────────────────────────────────────
        self.declare_parameter('input_topic',         '/hm30/image_raw')
        self.declare_parameter('output_topic',        '/hm30/pointcloud')
        self.declare_parameter('frame_id',            'hm30_camera')
        self.declare_parameter('device',              'cuda')
        self.declare_parameter('frame_skip',          1)        # process every frame
        self.declare_parameter('publish_every_n_frames', 5)    # publish cloud every N processed frames
        self.declare_parameter('conf_threshold',      3.0)
        self.declare_parameter('initial_winsize',     7)
        self.declare_parameter('keyframe_stride',     2)
        self.declare_parameter('win_r',               3)
        self.declare_parameter('num_scene_frame',     10)
        self.declare_parameter('buffer_size',         100)
        self.declare_parameter('retrieve_freq',       1)
        self.declare_parameter('min_publish_conf',    35.0)  # skip publish trigger if frame conf < this

        in_topic    = self.get_parameter('input_topic').value
        out_topic   = self.get_parameter('output_topic').value
        self._frame_id     = self.get_parameter('frame_id').value
        device             = self.get_parameter('device').value
        self._frame_skip   = max(1, self.get_parameter('frame_skip').value)
        self._pub_every    = max(1, self.get_parameter('publish_every_n_frames').value)
        conf_thres         = self.get_parameter('conf_threshold').value
        init_winsize       = self.get_parameter('initial_winsize').value
        kf_stride          = self.get_parameter('keyframe_stride').value
        win_r              = self.get_parameter('win_r').value
        num_scene_frame    = self.get_parameter('num_scene_frame').value
        buffer_size        = self.get_parameter('buffer_size').value
        retrieve_freq      = self.get_parameter('retrieve_freq').value
        min_pub_conf       = self.get_parameter('min_publish_conf').value

        self.get_logger().info(
            f"SLAM3R Bridge: {in_topic} → {out_topic} | "
            f"device={device} skip={self._frame_skip}"
        )

        # ── Publisher / Subscriber ────────────────────────────────────────────
        self._pub = self.create_publisher(PointCloud2, out_topic, 10)
        self._sub = self.create_subscription(Image, in_topic,
                                             self._on_image, 10)

        # ── Static TF broadcaster (map → hm30_camera) ─────────────────────────
        # This lets RViz display the cloud with Fixed Frame = "map".
        # Camera sits 1 m above the map origin looking down-forward.
        self._tf_broadcaster = tf2_ros.StaticTransformBroadcaster(self)
        self._broadcast_static_tf()

        # ── Frame counter ─────────────────────────────────────────────────────
        self._recv_count    = 0
        self._proc_count    = 0   # frames pushed to SLAM3R
        self._pub_count     = 0   # clouds published

        # ── SLAM3R worker ─────────────────────────────────────────────────────
        if _SLAM3R_AVAILABLE:
            args = _make_args(
                device=device,
                conf_thres_i2p=conf_thres,
                conf_thres_l2w=conf_thres * 8,   # tighter for final filter
                keyframe_stride=kf_stride,
                initial_winsize=init_winsize,
                win_r=win_r,
                num_scene_frame=num_scene_frame,
                buffer_size=buffer_size,
                retrieve_freq=retrieve_freq,
                min_publish_conf=min_pub_conf,
            )
            self._worker = SLAM3RWorker(
                device=device,
                args=args,
                on_pointcloud_ready=self._on_cloud_ready,
                logger=self.get_logger(),
            )
            self._worker.start()
        else:
            self._worker = None
            self.get_logger().warn("SLAM3R unavailable — no point clouds will be published.")

    def destroy_node(self):
        if self._worker:
            self.get_logger().info("Stopping SLAM3R worker…")
            self._worker.stop()
        super().destroy_node()

    def _broadcast_static_tf(self):
        """Publish a static TF: map → hm30_camera (identity).
        Since we transform the point cloud coordinates to ROS REP-103 convention
        before publishing, the camera frame coincides with the map origin.
        """
        t = TransformStamped()
        t.header.stamp    = self.get_clock().now().to_msg()
        t.header.frame_id = 'map'
        t.child_frame_id  = self._frame_id  # 'hm30_camera'
        # Identity: cloud coordinates are already in ROS (X-fwd, Y-left, Z-up)
        t.transform.translation.x = 0.0
        t.transform.translation.y = 0.0
        t.transform.translation.z = 0.0
        t.transform.rotation.x = 0.0
        t.transform.rotation.y = 0.0
        t.transform.rotation.z = 0.0
        t.transform.rotation.w = 1.0
        self._tf_broadcaster.sendTransform(t)
        self.get_logger().info(
            f"[TF] Published static transform: map → {self._frame_id} (identity)"
        )

    # ── Image callback ────────────────────────────────────────────────────────

    def _on_image(self, msg: Image):
        self._recv_count += 1
        if self._recv_count % self._frame_skip != 0:
            return
        if self._worker is None:
            return

        try:
            bgr = ros_image_to_bgr(msg)
        except Exception as exc:
            self.get_logger().warn(f"Image conversion failed: {exc}")
            return

        self._worker.push_frame(bgr)
        self._proc_count += 1
        if self._proc_count % 30 == 0:
            self.get_logger().info(
                f"[SLAM3R Bridge] Received {self._recv_count} frames, "
                f"pushed {self._proc_count} for reconstruction."
            )

    # ── Point cloud callback (called from SLAM3R worker thread) ───────────────

    def _on_cloud_ready(self, pts_xyz: np.ndarray, pts_rgb: np.ndarray):
        self._pub_count += 1
        if self._pub_count % self._pub_every != 0:
            return

        stamp = self.get_clock().now().to_msg()
        msg   = make_pointcloud2(pts_xyz, pts_rgb, self._frame_id, stamp)
        self._pub.publish(msg)
        print(
            f"[SLAM3R] Published cloud with {len(pts_xyz)} points "
            f"→ {self.get_parameter('output_topic').value}", flush=True
        )


# ══════════════════════════════════════════════════════════════════════════════
# Entry point
# ══════════════════════════════════════════════════════════════════════════════

def main():
    rclpy.init()
    node = SLAM3RBridgeNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
