# HM30 Stream Receiver — Machine Setup Walkthrough

Recorded: 2026-04-24 / updated 2026-04-25. Machine: `lahiru_s` desktop, Ubuntu 24.04, ROS2 Jazzy (custom build at `~/ros2_jazzy`).

---

## Table of Contents

1. [GUI Receiver — Stream from IP Webcam](#1-gui-receiver--stream-from-ip-webcam-android-app)
2. [Machine Path Migration](#2-machine-path-migration-xavier_ai--lahiru_s)
3. [ROS2 Distro Migration — Humble → Jazzy](#3-ros2-distro-migration--humble--jazzy)
4. [CycloneDDS Configuration](#4-cyclonedds-configuration)
5. [ROS2 Pipeline — Verification](#5-ros2-pipeline--verification)
6. [Laptop Webcam Stream Source](#6-laptop-webcam-stream-source)
7. [SLAM3R Bridge Setup](#7-slam3r-bridge-setup)
8. [New Machine Migration Guide](#8-new-machine-migration-guide)
9. [Quick-Start Commands](#9-quick-start-commands-this-machine)

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

### Create the config directory and file
```bash
mkdir -p /home/lahiru_s/cyclonedds
```

Create `/home/lahiru_s/cyclonedds/cyclonedx.xml`:

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<CycloneDDS xmlns="https://cdds.io/config"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:schemaLocation="https://cdds.io/config https://raw.githubusercontent.com/eclipse-cyclonedds/cyclonedds/master/etc/cyclonedds.xsd">
  <Domain id="any">
    <General>
      <Interfaces>
        <!-- Same-machine only: loopback is enough -->
        <NetworkInterface name="lo" multicast="true"/>

        <!-- Cross-host over wifi — uncomment and set correct interface name -->
        <!-- <NetworkInterface name="wlan0" multicast="true"/> -->

        <!-- Cross-host over ethernet — higher priority than wifi -->
        <!-- <NetworkInterface name="eth0" multicast="true" priority="1"/> -->
      </Interfaces>
    </General>

    <Discovery>
      <ParticipantIndex>auto</ParticipantIndex>
      <MaxAutoParticipantIndex>50</MaxAutoParticipantIndex>
      <!-- Unicast fallback when multicast blocked (common on wifi APs) -->
      <!--
      <Peers>
        <Peer address="192.168.1.10"/>
      </Peers>
      -->
    </Discovery>

    <SharedMemory>
      <!-- Set true only if Iceoryx RouDi daemon is running -->
      <!-- Without RouDi: node aborts with "Timeout registering at RouDi" -->
      <Enable>false</Enable>
    </SharedMemory>

    <Internal>
      <Watermarks>
        <!-- 80 MB accommodates large image frames without blocking publisher -->
        <WhcHigh>80MB</WhcHigh>
      </Watermarks>
    </Internal>

    <Tracing>
      <!-- Change to "config" during bringup to verify interface/peer selection -->
      <Verbosity>warning</Verbosity>
      <OutputFile>stderr</OutputFile>
    </Tracing>
  </Domain>
</CycloneDDS>
```

### Known failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `unknown element 'Size'` | Invalid XML element in `<SharedMemory>` | Only `Enable`, `Locator`, `LogLevel`, `Prefix` are valid children |
| `Timeout registering at RouDi` / core dump | `<Enable>true</Enable>` without Iceoryx daemon | Set `<Enable>false</Enable>` or start RouDi |
| `ros2 topic list` shows nothing | CLI not using same RMW + same XML | Export all 3 env vars — see §5 |
| Discovery fails across hosts | Multicast blocked by router/AP | Add remote IPs to `<Peers>` section |

### Enabling SHM (optional, requires Iceoryx)
```bash
# Install Iceoryx
sudo apt install ros-jazzy-iceoryx-hoofs ros-jazzy-iceoryx-posh

# Start RouDi daemon (must be running before any DDS node)
sudo iox-roudi

# Then set <Enable>true</Enable> in the XML
```

---

## 5. ROS2 Pipeline — Verification

### Environment Required for Any ROS2 CLI
```bash
source /home/lahiru_s/ros2_jazzy/install/setup.bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI=file:///home/lahiru_s/cyclonedds/cyclonedx.xml
```

**Why all three:** Publisher sets these in `run_receiver_internal.sh`. Any CLI tool (`topic list`, `hz`, `echo`) must use the same RMW + same CycloneDDS config to join the same DDS domain. Mismatched RMW = silent discovery failure — no error, just no topics visible.

### Verified Working
```
Subscription count: 1
height: 720 / width: 1280 / encoding: rgb8
data: '<sequence type: uint8, length: 2764800>'  # = 1280×720×3 ✓
```

**Note on `ros2 topic hz` false negative:** Must run `topic info` and `hz` simultaneously to see active subscription. `topic echo --no-arr` is the cleaner test.

---

## 6. Laptop Webcam Stream Source

### Problem
IP Webcam requires phone on same network. Laptop webcam (`/dev/video0`) is always available — cleaner for local testing.

### Discovery
```bash
v4l2-ctl --device=/dev/video0 --all
# Card type: HD Webcam: HD Webcam
# Width/Height: 1280/720
# Pixel Format: MJPG (Motion-JPEG)
```

### Created `scripts/stream_from_webcam.sh`

```bash
ffmpeg \
    -f v4l2 \
    -input_format mjpeg \
    -video_size 1280x720 \
    -framerate 30 \
    -i /dev/video0 \
    -c:v libx264 -preset ultrafast -tune zerolatency \
    -pix_fmt yuv420p -an \
    -f rtp "rtp://127.0.0.1:5600"
```

**Why `-input_format mjpeg`:** V4L2 can deliver raw YUYV or MJPEG. MJPEG read avoids kernel-side YUYV→RGB conversion, saving one decode step.

**Override device/port:**
```bash
bash scripts/stream_from_webcam.sh /dev/video1 5700
```

---

## 7. SLAM3R Bridge Setup

Full details in `docs/SLAM3R_SETUP_PROCESS.md`. Summary of what was done and why.

### Prerequisites
- SLAM3R source cloned + patched: `/home/lahiru_s/Desktop/projects/SLAM3R`
- GPU: RTX 5060 Ti 8GB (Blackwell, sm_120), requires torch 2.7.0+cu128
- ROS2 Jazzy rclpy compiled for **Python 3.12**

### Why a separate conda env (`slam3r_bridge`)

The existing `slam3r` conda env uses Python 3.11. Jazzy's rclpy C extensions are compiled for Python 3.12 — importing them from 3.11 causes ABI mismatch / `ImportError`. A new env with Python 3.12 shares the same major version as Jazzy's rclpy, so `source setup.bash` injects rclpy into `PYTHONPATH` and it loads cleanly.

### Task 5 — Create `slam3r_bridge` conda env

```bash
conda create -n slam3r_bridge python=3.12 -y
conda activate slam3r_bridge

# torch must match CUDA 12.8 (Blackwell requires cu128)
pip install torch==2.7.0+cu128 torchvision==0.22.0+cu128 \
    --index-url https://download.pytorch.org/whl/cu128

# SLAM3R deps (exclude pycuda — not needed for online pipeline)
cd /home/lahiru_s/Desktop/projects/SLAM3R
grep -v pycuda requirements.txt | pip install -r /dev/stdin

# Verify
python -c "import torch; print(torch.__version__, torch.cuda.is_available(), torch.cuda.get_device_name(0))"
# Expected: 2.7.0+cu128 True NVIDIA GeForce RTX 5060 Ti
```

### Task 6 — Verify rclpy importable in `slam3r_bridge`

```bash
source /home/lahiru_s/ros2_jazzy/install/setup.bash
conda run -n slam3r_bridge python -c "import rclpy; print('rclpy OK')"
```

If this fails — rclpy not on PYTHONPATH inside conda. Fix with a `.pth` file:
```bash
CONDA_SITE=$(conda run -n slam3r_bridge python -c "import site; print(site.getsitepackages()[0])")
echo "/home/lahiru_s/ros2_jazzy/install/rclpy/lib/python3.12/site-packages" \
    > "$CONDA_SITE/ros2_jazzy.pth"
# Re-verify
conda run -n slam3r_bridge python -c "import rclpy; print('rclpy OK')"
```

### Task 7 — `run_slam3r_bridge.sh` — what it does

`scripts/run_slam3r_bridge.sh` handles the full launch sequence:
1. Sources `.slam3r_env` (sets `SLAM3R_PATH`)
2. Sources Jazzy `setup.bash` (injects rclpy for Python 3.12)
3. Resolves `slam3r_bridge` conda env Python binary
4. Sets `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True` (prevents OOM on 8GB)
5. Sets RMW + CycloneDDS env vars
6. Sanity-checks `rclpy`, `torch+CUDA`, `slam3r` imports
7. Execs the bridge node

### Task 8 — Bridge node 8GB defaults

`slam3r_ros2/slam3r_bridge_node.py` `declare_parameter` defaults are set for RTX 5060 Ti 8GB:

| Parameter | Value | Rationale |
|---|---|---|
| `keyframe_stride` | `3` | Online mode — lower than offline's 30 |
| `win_r` | `3` | Local window radius |
| `num_scene_frame` | `3` | Scene frames in memory |
| `max_num_register` | `4` | Max frames registered per cycle |
| `initial_winsize` | `5` | Bootstrap window size |
| `conf_threshold` (i2p) | `1.5` | Point confidence filter |
| `conf_threshold_l2w` | `10.0` | Global registration threshold |
| `num_points_save` | `500000` | Downsample to 500k pts before publish |

Override at runtime:
```bash
bash scripts/run_slam3r_bridge.sh --ros-args -p frame_skip:=2 -p initial_winsize:=7
```

### Task 9 — Full pipeline (confirmed working)

Start in order — 4 terminals:

```bash
# T1 — stream relay (pick one)
bash scripts/stream_from_ipcam.sh
# or
bash scripts/stream_from_webcam.sh

# T2 — ROS2 publisher
bash scripts/run_receiver_internal.sh

# T3 — SLAM3R bridge
bash scripts/run_slam3r_bridge.sh

# T4 — verify
source /home/lahiru_s/ros2_jazzy/install/setup.bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI=file:///home/lahiru_s/cyclonedds/cyclonedx.xml
ros2 topic hz /hm30/pointcloud
# or
python3 scripts/_diag_pointcloud.py

# Optional — RViz2
bash scripts/run_rviz_shm.sh
```

---

## 8. New Machine Migration Guide

When deploying on a new machine, update these locations. All hardcoded paths are per-machine.

### Step 1 — Identify your values

```bash
# Your username
whoami

# ROS2 setup.bash location
# System install:  /opt/ros/<distro>/setup.bash
# Custom build:    ~/ros2_<distro>/install/setup.bash
find ~ /opt/ros -name "setup.bash" 2>/dev/null | head -5

# Python version used by your ROS2 rclpy
find ~/ros2_*/install /opt/ros -path "*/rclpy/lib/python*/site-packages" 2>/dev/null | head -3

# Miniconda/Anaconda base
conda info --base

# SLAM3R install dir (wherever you cloned it)
ls ~/Desktop/projects/SLAM3R 2>/dev/null || ls ~/SLAM3R 2>/dev/null
```

### Step 2 — Bulk replace in scripts

```bash
cd /path/to/hm30_stream_reciever

OLD_USER="lahiru_s"
NEW_USER="$(whoami)"

# Replace username in all scripts and env files
sed -i "s|/home/$OLD_USER/|/home/$NEW_USER/|g" \
    scripts/*.sh \
    scripts/*.py \
    slam3r_ros2/.slam3r_env \
    slam3r_ros2/slam3r_bridge_node.py
```

### Step 3 — Update `.slam3r_env`

Edit `slam3r_ros2/.slam3r_env`:
```bash
export SLAM3R_PATH="/home/<your-user>/path/to/SLAM3R"
export CONDA_ENV_NAME="slam3r_bridge"
```

### Step 4 — Create CycloneDDS config

```bash
mkdir -p /home/<your-user>/cyclonedds
# Copy the XML from §4 above
# Edit NetworkInterface name to match your interface (ip link show)
```

Update `CYCLONEDDS_URI` in these scripts if the config path differs:
- `scripts/run_receiver_internal.sh`
- `scripts/run_slam3r_bridge.sh`
- `scripts/run_rviz_shm.sh`
- `scripts/run_slam3r_external.sh`

### Step 5 — Update ROS2 setup.bash path

If using a different distro or install location, update these scripts:
- `scripts/run_receiver_internal.sh` — line `source /home/.../setup.bash`
- `scripts/run_slam3r_bridge.sh` — same
- `scripts/run_rviz_shm.sh` — same
- `scripts/install_slam3r.sh` — Python site-packages path

### Step 6 — Rebuild the C++ binary

```bash
source /path/to/ros2/setup.bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
make -C build -j$(nproc)
# Verify ROS2 publisher enabled:
# "ROS2 publisher : ENABLED  (topic /hm30/image_raw)"
```

### Step 7 — Create `slam3r_bridge` conda env

Follow §7 Task 5–6 above. Key check: your conda Python major version must match the Python version in your ROS2 rclpy path.

```bash
# Find rclpy Python version
find /path/to/ros2/install -path "*/rclpy/lib/python*/site-packages" 2>/dev/null
# → .../python3.12/... means conda env must be Python 3.12
```

### Step 8 — Verify full pipeline

```bash
# Check all 3 imports in the bridge env
bash scripts/_test_bridge_imports.sh
```

### Machine-specific values (this machine — lahiru_s desktop)

| Setting | Value |
|---|---|
| Username | `lahiru_s` |
| ROS2 setup.bash | `/home/lahiru_s/ros2_jazzy/install/setup.bash` |
| ROS2 distro | Jazzy (custom build) |
| rclpy Python version | 3.12 |
| CycloneDDS config | `/home/lahiru_s/cyclonedds/cyclonedx.xml` |
| SLAM3R dir | `/home/lahiru_s/Desktop/projects/SLAM3R` |
| Conda base | `/home/lahiru_s/miniconda3` |
| Bridge conda env | `slam3r_bridge` (Python 3.12) |
| GPU | RTX 5060 Ti 8GB, CUDA 12.8, torch 2.7.0+cu128 |
| SHM | Disabled (no Iceoryx RouDi) |
| Network interfaces | `lo` only (same-machine pipeline) |

---

## 9. Quick-Start Commands (This Machine)

### Stream sources (pick one)
```bash
# Android IP Webcam (192.168.8.176:8080)
bash scripts/stream_from_ipcam.sh

# Laptop webcam (/dev/video0)
bash scripts/stream_from_webcam.sh
```

### Receiver mode A — GUI viewer only
```bash
./build/hm30_rtp_receiver
```

### Receiver mode B — Full SLAM3R pipeline (4 terminals)
```bash
# T1
bash scripts/stream_from_webcam.sh

# T2
bash scripts/run_receiver_internal.sh

# T3
bash scripts/run_slam3r_bridge.sh

# T4 — RViz2 (optional)
bash scripts/run_rviz_shm.sh
```

### Verify topics
```bash
source /home/lahiru_s/ros2_jazzy/install/setup.bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI=file:///home/lahiru_s/cyclonedds/cyclonedx.xml

ros2 topic echo /hm30/image_raw --no-arr     # 1280×720 rgb8
ros2 topic hz /hm30/pointcloud               # SLAM3R output
python3 scripts/_diag_pointcloud.py          # XYZ stats + NaN/Inf count
```

> GUI receiver and ROS2 publisher cannot run simultaneously — both bind UDP :5600.
