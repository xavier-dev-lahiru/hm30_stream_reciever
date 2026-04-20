#!/usr/bin/env bash
# Dry-run test of the bridge setup - checks all imports without launching ROS2 node
set -e

CONDA_BASE=$(conda info --base)
SLAM3R_DIR=/home/xavier_ai/Documents/SLAM3R
PYTHON_BIN=/usr/bin/python3

source /opt/ros/humble/setup.bash
# Only SLAM3R in PYTHONPATH — torch/numpy installed directly in system Python 3.10 user site
export PYTHONPATH="$SLAM3R_DIR:${PYTHONPATH:-}"

echo "=== Python: $($PYTHON_BIN --version) ==="
echo "=== PYTHONPATH (first 100): ${PYTHONPATH:0:100}... ==="
echo ""

echo "[1/5] Testing rclpy..."
$PYTHON_BIN -c "import rclpy; print('  OK - rclpy', rclpy.__version__ if hasattr(rclpy,'__version__') else 'loaded')"

echo "[2/5] Testing sensor_msgs..."
$PYTHON_BIN -c "from sensor_msgs.msg import Image, PointCloud2; print('  OK - sensor_msgs Image + PointCloud2')"

echo "[3/5] Testing torch + CUDA..."
$PYTHON_BIN -c "import torch; print(f'  OK - PyTorch {torch.__version__} | CUDA: {torch.cuda.is_available()} | GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else None}')"

echo "[4/5] Testing slam3r..."
$PYTHON_BIN -c "import slam3r; print('  OK - slam3r from', slam3r.__file__)"

echo "[5/5] Testing slam3r models import..."
$PYTHON_BIN -c "
from slam3r.models import Image2PointsModel, Local2WorldModel, inf
from slam3r.pipeline.recon_online_pipeline import (
    get_raw_input_frame, process_input_frame,
    initial_scene_for_accumulated_frames,
    pointmap_local_recon, pointmap_global_register
)
print('  OK - all SLAM3R pipeline functions importable')
"

echo ""
echo "========================================"
echo " All checks PASSED - bridge is ready!"
echo " Run: bash scripts/run_slam3r_bridge.sh"
echo "========================================"
