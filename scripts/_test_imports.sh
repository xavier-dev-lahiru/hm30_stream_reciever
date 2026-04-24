#!/usr/bin/env bash
CONDA_PYTHON=/home/lahiru_s/miniconda/envs/slam3r/bin/python3
echo "=== Testing rclpy import in conda Python 3.11 ==="
$CONDA_PYTHON -c "import rclpy; print('rclpy OK:', rclpy.__file__)" 2>&1 | head -5
echo "=== Testing slam3r import ==="
$CONDA_PYTHON -c "import slam3r; print('slam3r OK:', slam3r.__file__)"
echo "=== Testing sensor_msgs import ==="
$CONDA_PYTHON -c "from sensor_msgs.msg import Image; print('sensor_msgs OK')" 2>&1 | head -5
