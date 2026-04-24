# HM30 Stream Receiver — Machine Setup Walkthrough

Recorded: 2026-04-24. Machine: `lahiru_s` desktop, Ubuntu 24.04, ROS2 Jazzy (custom build at `~/ros2_jazzy`).

---

## 1. GUI Receiver — Stream from IP Webcam Android App

### Problem
Project expects H.264 RTP from a SIYI HM30 radio link on UDP :5600.
Test machine has no HM30 — used Android **IP Webcam** app (192.168.8.176:8080) instead.

### Discovery
```bash
curl -I http://192.168.8.176:8080/
# Server: IP Webcam Server 0.4

ffprobe -show_streams http://192.168.8.176:8080/video?type=mp4
# codec: mjpeg — NOT H.264 despite the mp4 URL param
```

`/video?type=mp4` returns MJPEG (payload type 26). Receiver SDP expects H.264 (payload type 96). Direct stream copy failed silently.

### Fix — FFmpeg Relay with Transcode
Created `scripts/stream_from_ipcam.sh`:

```bash
ffmpeg -fflags nobuffer -flags low_delay \
  -i "http://192.168.8.176:8080/video?type=mp4" \
  -c:v libx264 -preset ultrafast -tune zerolatency \
  -pix_fmt yuv420p -an \
  -f rtp "rtp://127.0.0.1:5600"
```

**Why transcode:** MJPEG → RTP sends payload type 26; receiver SDP declares PT=96 (H.264). FFmpeg `stream copy` passes MJPEG packets through unchanged — receiver's `avformat_open_input` times out waiting for valid H.264 NAL units.

**Why `ultrafast/zerolatency`:** 1920×1080 MJPEG @ 25fps needs CPU transcode. Ultrafast preset minimises encode latency at cost of compression ratio. Zerolatency disables B-frames and lookahead, keeping end-to-end delay under ~200 ms.

### Result
GUI receiver (`./build/hm30_rtp_receiver`) shows **1920×1080 @ 30.5 FPS, H.264, LIVE**.

---

## 2. Machine Path Migration (`xavier_ai` → `lahiru_s`)

### Problem
All scripts hardcoded `/home/xavier_ai/...` (original development machine).

### Files Changed
| File | What changed |
|---|---|
| `scripts/run_receiver_internal.sh` | `CYCLONEDDS_URI` path |
| `scripts/run_slam3r_external.sh` | `CYCLONEDDS_URI` path |
| `scripts/run_rviz_shm.sh` | `CYCLONEDDS_URI` path |
| `scripts/_test_bridge_imports.sh` | `SLAM3R_DIR` path |
| `scripts/_fix_slam3r_paths.sh` | `SLAM3R_DIR` path |
| `scripts/_diag_pointcloud.py` | `sys.path.insert` path |
| `scripts/_test_imports.sh` | `CONDA_PYTHON` path |
| `scripts/install_slam3r.sh` | ROS Python path + setup.bash ref |
| `slam3r_ros2/.slam3r_env` | `SLAM3R_PATH` |
| `slam3r_ros2/slam3r_bridge_node.py` | setup.bash comment |

```bash
# Bulk replace (run from project root)
sed -i 's|/home/xavier_ai/|/home/lahiru_s/|g' scripts/*.sh slam3r_ros2/.slam3r_env slam3r_ros2/slam3r_bridge_node.py scripts/_diag_pointcloud.py
```

---

## 3. ROS2 Distro Migration — Humble → Jazzy

### Problem
Scripts source `/opt/ros/humble/setup.bash`. This machine has ROS2 Jazzy built from source at `~/ros2_jazzy/install/setup.bash`. `rosdev` is a shell alias that sources it.

### Files Changed
Same files as §2 — the `sed` pass also replaced setup.bash paths.

**New path:** `/home/lahiru_s/ros2_jazzy/install/setup.bash`

**Python site-packages path** (install_slam3r.sh) updated from:
```
/opt/ros/humble/lib/python3.10/dist-packages
```
to:
```
/home/lahiru_s/ros2_jazzy/install/lib/python3.12/site-packages
```

### CMake Build
```bash
source /home/lahiru_s/ros2_jazzy/install/setup.bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
make -C build -j$(nproc) hm30_ros2_publisher
```

CMake output confirmed: `ROS2 publisher : ENABLED  (topic /hm30/image_raw)`

---

## 4. CycloneDDS Configuration

### Problem
`run_receiver_internal.sh` sets `CYCLONEDDS_URI=file:///home/lahiru_s/cyclonedds/cyclonedx.xml` but that file (and directory) did not exist.

### Created `/home/lahiru_s/cyclonedds/cyclonedx.xml`

**Iteration 1 — failed:** Included `<Size>`, `<SubQueueCapacity>`, `<SubHistoryRequest>` in `<SharedMemory>`. These are not valid elements in this version of CycloneDDS (Jazzy). Node aborted with `unknown element` errors.

**Fix:** Checked schema at `~/ros2_jazzy/src/eclipse-cyclonedds/cyclonedds/etc/cyclonedds.xsd`. Valid `SharedMemory` children: `Enable`, `Locator`, `LogLevel`, `Prefix` only.

**Iteration 2 — failed:** `<Enable>true</Enable>` requires **Iceoryx RouDi** daemon running. Without it: `Timeout registering at RouDi` → `Aborted (core dumped)`.

**Why:** CycloneDDS SHM transport uses Iceoryx as the shared memory broker. RouDi is its daemon. Absent on this machine.

**Final config — SHM disabled:**
```xml
<SharedMemory>
  <Enable>false</Enable>
</SharedMemory>
```

Full config at `/home/lahiru_s/cyclonedds/cyclonedx.xml`. Loopback UDP is sufficient for same-machine inter-process video (no measurable latency vs SHM at this scale).

---

## 5. ROS2 Pipeline — Current State (In Progress)

### Working
- `bash scripts/run_receiver_internal.sh` starts `hm30_ros2_publisher`
- Decoder connects: `Stream connected: 1920x1080 codec:h264`
- `ros2 topic list` (with matching env) shows `/hm30/image_raw`

### Environment Required for Any ROS2 CLI
```bash
source /home/lahiru_s/ros2_jazzy/install/setup.bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI=file:///home/lahiru_s/cyclonedds/cyclonedx.xml
```

**Why all three:** Publisher sets these in `run_receiver_internal.sh`. Any CLI tool (topic list, hz, echo) must use the same RMW + same CycloneDDS config to join the same DDS domain. Mismatched RMW = silent discovery failure (sharp edge: no error, just no connection).

### Pending Issue
`ros2 topic hz /hm30/image_raw` hangs — subscription count shows 0 despite topic being listed. Under investigation.

**Possible causes:**
- Loopback multicast not delivering DDS discovery between processes
- Publisher not calling `publish()` (FPS shown is decode FPS, not publish FPS)
- CycloneDDS `<NetworkInterface name="lo">` restriction blocking peer discovery on same host

---

## Quick-Start Commands (This Machine)

```bash
# Terminal 1 — IP cam relay
bash scripts/stream_from_ipcam.sh

# Terminal 2 — GUI viewer (no ROS2)
./build/hm30_rtp_receiver

# Terminal 2 (alt) — ROS2 publisher
bash scripts/run_receiver_internal.sh

# Terminal 3 — verify ROS2 topic
source /home/lahiru_s/ros2_jazzy/install/setup.bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI=file:///home/lahiru_s/cyclonedds/cyclonedx.xml
ros2 topic hz /hm30/image_raw
```

> Note: GUI receiver and ROS2 publisher cannot run simultaneously — both bind UDP :5600.
