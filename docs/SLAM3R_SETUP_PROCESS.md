# SLAM3R Bridge Setup Process

## Status

| Task | Description | Status |
|---|---|---|
| 1–4 | Machine migration, path updates, env file | ✅ Done |
| 5 | Create `slam3r_bridge` conda env (Python 3.12 + torch 2.7+cu128) | ✅ Done |
| 6 | Verify rclpy importable in `slam3r_bridge` env | ✅ Done |
| 7 | `run_slam3r_bridge.sh` updated (correct python bin, CUDA alloc conf) | ✅ Done |
| 8 | Bridge node defaults set to 8GB params, imports verified | ✅ Done |
| 9 | Full pipeline run, `/hm30/pointcloud` confirmed | ✅ Done |
| 10 | Docs + memory updated | ✅ Done |

All tasks complete. Pipeline ready.

---

---

## Task 5 — Create slam3r_bridge conda env

```bash
conda create -n slam3r_bridge python=3.12 -y
conda activate slam3r_bridge
pip install torch==2.7.0+cu128 torchvision==0.22.0+cu128 --index-url https://download.pytorch.org/whl/cu128
cd /home/lahiru_s/Desktop/projects/SLAM3R
grep -v pycuda requirements.txt | pip install -r /dev/stdin
```

Verify:
```bash
python -c "import torch; print(torch.__version__, torch.cuda.is_available(), torch.cuda.get_device_name(0))"
```

Expected: `2.7.0+cu128 True NVIDIA GeForce RTX 5060 Ti`

---

## Task 6 — Verify rclpy importable in slam3r_bridge env

```bash
source /home/lahiru_s/ros2_jazzy/install/setup.bash
conda run -n slam3r_bridge python -c "import rclpy; print('rclpy OK')"
```

If fails — rclpy not on PYTHONPATH inside conda. Fix:
```bash
# Find rclpy site-packages path
find /home/lahiru_s/ros2_jazzy/install -name "rclpy" -type d 2>/dev/null

# Add to conda env's sitecustomize or use .pth file
CONDA_ENV_PATH=$(conda run -n slam3r_bridge python -c "import site; print(site.getsitepackages()[0])")
echo "/home/lahiru_s/ros2_jazzy/install/rclpy/lib/python3.12/site-packages" > "$CONDA_ENV_PATH/ros2_jazzy.pth"

# Re-verify
conda run -n slam3r_bridge python -c "import rclpy; print('rclpy OK')"
```

---

## Task 7 — Update run_slam3r_bridge.sh

Edit `scripts/run_slam3r_bridge.sh`:

- Change `PYTHON_BIN` to slam3r_bridge conda env python:
  ```
  PYTHON_BIN=$(conda run -n slam3r_bridge which python)
  ```
  Or hardcode:
  ```
  PYTHON_BIN=/home/lahiru_s/miniconda3/envs/slam3r_bridge/bin/python
  ```

- Add env var before exec:
  ```bash
  export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
  ```

- Set default ROS args (if none passed):
  ```
  win_r:=3 num_scene_frame:=3 max_num_register:=4 keyframe_stride:=3 initial_winsize:=5
  ```

- Remove old PYTHONPATH lines that injected conda torch (torch now in env).

After editing, verify script is executable:
```bash
chmod +x scripts/run_slam3r_bridge.sh
bash -n scripts/run_slam3r_bridge.sh  # syntax check
```

---

## Task 8 — Update slam3r_bridge_node.py defaults

Edit `slam3r_ros2/slam3r_bridge_node.py` — change `declare_parameter` defaults to 8GB values:

| Parameter | Default |
|---|---|
| `keyframe_stride` | `3` |
| `win_r` | `3` |
| `num_scene_frame` | `3` |
| `max_num_register` | `4` |
| `initial_winsize` | `5` |
| `conf_thres_i2p` | `1.5` |
| `conf_thres_l2w` | `10.0` |
| `num_points_save` | `500000` |

Also check imports work against patched SLAM3R source:
```bash
source /home/lahiru_s/ros2_jazzy/install/setup.bash
export PYTHONPATH=/home/lahiru_s/Desktop/projects/SLAM3R:$PYTHONPATH
conda run -n slam3r_bridge bash scripts/_test_bridge_imports.sh
```

---

## Task 9 — Full pipeline run

Start in order (separate terminals):

**Terminal 1 — stream relay:**
```bash
bash scripts/stream_from_ipcam.sh
# or for webcam test:
bash scripts/stream_from_webcam.sh
```

**Terminal 2 — ROS2 publisher:**
```bash
source /home/lahiru_s/ros2_jazzy/install/setup.bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI=file:///home/lahiru_s/cyclonedds/cyclonedx.xml
./build/hm30_ros2_publisher
```

**Terminal 3 — SLAM3R bridge:**
```bash
bash scripts/run_slam3r_bridge.sh
```

**Terminal 4 — verify pointcloud:**
```bash
source /home/lahiru_s/ros2_jazzy/install/setup.bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI=file:///home/lahiru_s/cyclonedds/cyclonedx.xml
ros2 topic hz /hm30/pointcloud
ros2 topic echo /hm30/pointcloud --no-arr | head -40
python3 scripts/_diag_pointcloud.py
```

**Optional — RViz2:**
```bash
bash scripts/run_rviz_shm.sh
```

---

## Task 10 — Update docs and memory

After pipeline confirmed working:

```bash
# Update walkthrough doc
# Edit docs/SETUP_WALKTHROUGH.md — add slam3r_bridge env section
```

Tell Claude: "task 10 done, update SLAM3R plan memory to all complete."

---

## 8GB Optimal Params Reference

| Param | Value |
|---|---|
| keyframe_stride | 3 |
| win_r | 3 |
| num_scene_frame | 3 |
| max_num_register | 4 |
| initial_winsize | 5 |
| conf_thres_i2p | 1.5 |
| conf_thres_l2w | 10 |
| num_points_save | 500000 |
| PYTORCH_CUDA_ALLOC_CONF | expandable_segments:True |
