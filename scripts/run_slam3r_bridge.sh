#!/usr/bin/env bash
# =============================================================================
# run_slam3r_bridge.sh
# Launches the SLAM3R ROS2 bridge node using:
#   - System Python 3.10  (needed for rclpy C extensions built for Python 3.10)
#   - SLAM3R + PyTorch    (injected from the slam3r conda env via PYTHONPATH)
#
# Usage:
#   bash scripts/run_slam3r_bridge.sh
#   bash scripts/run_slam3r_bridge.sh --ros-args -p frame_skip:=1 -p initial_winsize:=7
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NODE_SCRIPT="$PROJECT_DIR/slam3r_ros2/slam3r_bridge_node.py"
ENV_FILE="$PROJECT_DIR/slam3r_ros2/.slam3r_env"
CONDA_ENV="slam3r"

# ── Load .slam3r_env (sets SLAM3R_PATH) ──────────────────────────────────────
if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
else
    echo "[WARN] .slam3r_env not found — run scripts/install_slam3r.sh first."
fi

# ── Source ROS2 (provides rclpy, sensor_msgs for system Python 3.10) ─────────
if [ -f /opt/ros/humble/setup.bash ]; then
    set +u  # ROS2 setup.bash uses unbound vars internally
    source /opt/ros/humble/setup.bash
    set -u
else
    echo "[ERROR] ROS2 Humble not found at /opt/ros/humble"; exit 1
fi

# ── Build PYTHONPATH: add SLAM3R source tree to system Python 3.10 ───────────
# PyTorch, numpy, einops etc. are now installed in ~/.local (system Python 3.10)
# so we ONLY need to add the SLAM3R source directory.
CONDA_BASE=$(conda info --base 2>/dev/null || echo "$HOME/miniconda")
SLAM3R_DIR="${SLAM3R_PATH:-$HOME/Documents/SLAM3R}"

export PYTHONPATH="$SLAM3R_DIR:${PYTHONPATH:-}"
export SLAM3R_PATH="$SLAM3R_DIR"

# Use system Python 3.10 (has rclpy)
PYTHON_BIN="/usr/bin/python3"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " HM30 → SLAM3R → ROS2 PointCloud Bridge"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Python        : $PYTHON_BIN ($(${PYTHON_BIN} --version 2>&1))"
echo " SLAM3R path   : $SLAM3R_DIR"
echo " Conda env     : $CONDA_ENV (PyTorch/numpy from here)"
echo " PYTHONPATH    : ${PYTHONPATH:0:80}..."
echo " Subscribing   : /hm30/image_raw"
echo " Publishing    : /hm30/pointcloud"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Quick sanity check before launching
echo "[CHECK] rclpy..."
$PYTHON_BIN -c "import rclpy; print('  rclpy OK')" 2>&1 || { echo "[ERROR] rclpy not importable"; exit 1; }
echo "[CHECK] torch + CUDA..."
$PYTHON_BIN -c "import torch; print(f'  torch {torch.__version__} | CUDA: {torch.cuda.is_available()}')" 2>&1 || { echo "[ERROR] torch not importable — check PYTHONPATH"; exit 1; }
echo "[CHECK] slam3r..."
$PYTHON_BIN -c "import slam3r; print('  slam3r OK')" 2>&1 || { echo "[ERROR] slam3r not importable — check SLAM3R_PATH"; exit 1; }
echo ""

# ── Launch the node ───────────────────────────────────────────────────────────
exec $PYTHON_BIN "$NODE_SCRIPT" "$@"

