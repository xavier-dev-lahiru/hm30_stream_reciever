#!/usr/bin/env bash
# =============================================================================
# run_slam3r_bridge.sh
# Launches the SLAM3R ROS2 bridge node using:
#   - slam3r_bridge conda env (Python 3.12) — has torch 2.7.0+cu128 + SLAM3R deps
#   - Jazzy rclpy injected via PYTHONPATH (compiled for Python 3.12)
#   - SLAM3R source injected via PYTHONPATH
#
# Usage:
#   bash scripts/run_slam3r_bridge.sh
#   bash scripts/run_slam3r_bridge.sh --ros-args -p frame_skip:=2
#
# Defaults (8 GB GPU config — RTX 5060 Ti):
#   keyframe_stride=3  win_r=3  num_scene_frame=3  max_num_register=4
#   initial_winsize=5  conf_threshold=1.5  conf_threshold_l2w=10
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NODE_SCRIPT="$PROJECT_DIR/slam3r_ros2/slam3r_bridge_node.py"
ENV_FILE="$PROJECT_DIR/slam3r_ros2/.slam3r_env"
CONDA_ENV="slam3r_bridge"

# ── Load .slam3r_env (sets SLAM3R_PATH) ──────────────────────────────────────
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "[WARN] .slam3r_env not found — SLAM3R_PATH may not be set."
fi

# ── Source ROS2 Jazzy (injects rclpy for Python 3.12 into PYTHONPATH) ────────
if [ -f /home/lahiru_s/ros2_jazzy/install/setup.bash ]; then
    set +u
    source /home/lahiru_s/ros2_jazzy/install/setup.bash
    set -u
else
    echo "[ERROR] ROS2 Jazzy not found at /home/lahiru_s/ros2_jazzy/install/setup.bash"; exit 1
fi

# ── Resolve conda env Python ──────────────────────────────────────────────────
CONDA_BASE=$(conda info --base 2>/dev/null || echo "$HOME/miniconda3")
PYTHON_BIN="$CONDA_BASE/envs/$CONDA_ENV/bin/python"

if [ ! -f "$PYTHON_BIN" ]; then
    echo "[ERROR] Conda env '$CONDA_ENV' not found at $PYTHON_BIN"
    echo "  Create it: conda create -n slam3r_bridge python=3.12 -y"
    exit 1
fi

# ── SLAM3R on PYTHONPATH ──────────────────────────────────────────────────────
SLAM3R_DIR="${SLAM3R_PATH:-$HOME/Desktop/projects/SLAM3R}"
export PYTHONPATH="$SLAM3R_DIR:${PYTHONPATH:-}"
export SLAM3R_PATH="$SLAM3R_DIR"

# ── GPU memory tuning (required for 8 GB GPU) ─────────────────────────────────
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

# ── RMW / CycloneDDS ─────────────────────────────────────────────────────────
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI=file:///home/lahiru_s/cyclonedds/cyclonedx.xml

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " HM30 → SLAM3R → ROS2 PointCloud Bridge"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Python        : $PYTHON_BIN ($($PYTHON_BIN --version 2>&1))"
echo " Conda env     : $CONDA_ENV"
echo " SLAM3R path   : $SLAM3R_DIR"
echo " PYTHONPATH    : ${PYTHONPATH:0:100}..."
echo " RMW           : $RMW_IMPLEMENTATION"
echo " Subscribing   : /hm30/image_raw"
echo " Publishing    : /hm30/pointcloud"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Sanity checks ─────────────────────────────────────────────────────────────
echo "[CHECK] rclpy..."
$PYTHON_BIN -c "import rclpy; print('  rclpy OK')" 2>&1 || {
    echo "[ERROR] rclpy not importable in $CONDA_ENV env."
    echo "  Make sure Jazzy is sourced — its setup.bash adds rclpy to PYTHONPATH."
    exit 1
}
echo "[CHECK] torch + CUDA..."
$PYTHON_BIN -c "import torch; print(f'  torch {torch.__version__} | CUDA: {torch.cuda.is_available()} | GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"none\"}')" 2>&1 || {
    echo "[ERROR] torch not importable — install: pip install torch==2.7.0+cu128"
    exit 1
}
echo "[CHECK] slam3r..."
$PYTHON_BIN -c "import slam3r; print('  slam3r OK')" 2>&1 || {
    echo "[ERROR] slam3r not importable — check SLAM3R_PATH: $SLAM3R_DIR"
    exit 1
}
echo ""

# ── Launch ────────────────────────────────────────────────────────────────────
exec $PYTHON_BIN "$NODE_SCRIPT" "$@"
