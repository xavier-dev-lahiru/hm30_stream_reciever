#!/usr/bin/env bash
# =============================================================================
# stream_from_webcam.sh
#
# Stream laptop webcam as H.264 RTP to hm30_rtp_receiver / hm30_ros2_publisher.
#
# Usage:
#   bash scripts/stream_from_webcam.sh [DEVICE] [RTP_PORT]
#
# Defaults: DEVICE=/dev/video0  RTP_PORT=5600
#
# List devices:  v4l2-ctl --list-devices
# Check formats: v4l2-ctl --device=/dev/video0 --list-formats-ext
# =============================================================================

set -euo pipefail

DEVICE="${1:-/dev/video0}"
RTP_PORT="${2:-5600}"
RTP_DST="rtp://127.0.0.1:${RTP_PORT}"

if [ ! -e "${DEVICE}" ]; then
    echo "[ERROR] Device ${DEVICE} not found."
    echo "  Available: $(ls /dev/video* 2>/dev/null | tr '\n' ' ')"
    exit 1
fi

echo "================================================================"
echo " Webcam → RTP relay"
echo "  Device : ${DEVICE}"
echo "  Dest   : ${RTP_DST} (UDP)"
echo "================================================================"
echo " Make sure hm30_rtp_receiver or hm30_ros2_publisher is running"
echo "================================================================"

exec ffmpeg \
    -hide_banner \
    -loglevel warning \
    -f v4l2 \
    -input_format mjpeg \
    -video_size 1280x720 \
    -framerate 30 \
    -i "${DEVICE}" \
    -c:v libx264 \
    -preset ultrafast \
    -tune zerolatency \
    -pix_fmt yuv420p \
    -an \
    -f rtp \
    "${RTP_DST}"
