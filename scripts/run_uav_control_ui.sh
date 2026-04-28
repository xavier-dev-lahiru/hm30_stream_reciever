#!/usr/bin/env bash
# =============================================================================
# run_uav_control_ui.sh
#
# Starts the UAV Control UI — a Qt5/QML application backed by a ROS 2 node
# (uav_control_ui_node) that subscribes to camera frames, drone-pad status,
# and gimbal topics while providing joystick/action controls via a native
# Qt/QML interface.
#
# Prerequisites
#   - ROS 2 Humble installed at /opt/ros/humble
#   - Local workspace built via `colcon build` (provides uav_control_ui_cpp
#     and local cognition_brain_interfaces)
#   - CycloneDDS config at /home/xavier_ai/cyclonedds/cyclonedx.xml
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BINARY="$PROJECT_DIR/src/uav_control_ui_cpp/build/uav_control_ui"

# ---------------------------------------------------------------------------
# Source ROS 2 Humble
# ---------------------------------------------------------------------------
if [ -f /opt/ros/humble/setup.bash ]; then
    set +u
    source /opt/ros/humble/setup.bash
    set -u
else
    echo "[ERROR] ROS 2 Humble not found at /opt/ros/humble"
    exit 1
fi

# ---------------------------------------------------------------------------
# Source the local workspace overlay (provides both the uav_control_ui_cpp
# and the local cognition_brain_interfaces type-support libs)
# ---------------------------------------------------------------------------
LOCAL_SETUP="$PROJECT_DIR/install/setup.bash"
if [ -f "$LOCAL_SETUP" ]; then
    set +u
    source "$LOCAL_SETUP"
    set -u
else
    echo "[WARN] Local workspace overlay not found at $LOCAL_SETUP"
    echo "       Please run 'colcon build' in $PROJECT_DIR"
fi

BINARY="$PROJECT_DIR/install/uav_control_ui_cpp/lib/uav_control_ui_cpp/uav_control_ui"

# ---------------------------------------------------------------------------
# Verify the binary exists
# ---------------------------------------------------------------------------
if [ ! -f "$BINARY" ]; then
    # Fallback to the old raw-CMake build path if someone didn't use colcon
    BINARY_FALLBACK="$PROJECT_DIR/src/uav_control_ui_cpp/build/uav_control_ui"
    if [ -f "$BINARY_FALLBACK" ]; then
        BINARY="$BINARY_FALLBACK"
    else
        echo "[ERROR] UAV Control UI binary not found."
        echo ""
        echo "  Build the workspace first with:"
        echo "    cd $PROJECT_DIR"
        echo "    source /opt/ros/humble/setup.bash"
        echo "    colcon build"
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# DDS configuration — use CycloneDDS (consistent with other services)
# ---------------------------------------------------------------------------
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI=file:///home/xavier_ai/cyclonedds/cyclonedx.xml

# ---------------------------------------------------------------------------
# Qt / display configuration
# ---------------------------------------------------------------------------
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"

echo "==========================================================="
echo " Starting UAV Control UI"
echo "==========================================================="
echo "  Binary  : $BINARY"
echo "  RMW     : $RMW_IMPLEMENTATION"
echo "  Display : ${DISPLAY:-<not set>}"
echo "==========================================================="

# ---------------------------------------------------------------------------
# Background Services
# ---------------------------------------------------------------------------
echo ">>> Starting local background video receiver..."
"$PROJECT_DIR/scripts/run_receiver_internal.sh" &
RECEIVER_PID=$!

# Ensure background processes are killed when this script exits
trap 'echo ">>> Stopping background video receiver..."; kill $RECEIVER_PID 2>/dev/null || true' EXIT

# ---------------------------------------------------------------------------
# Run the UI (blocking)
# ---------------------------------------------------------------------------
"$BINARY" "$@"
