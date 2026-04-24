#!/usr/bin/env bash
# =============================================================================
# stream_from_ipcam.sh
#
# Relay H.264 from an IP Webcam Android app to the hm30_rtp_receiver.
#
# Usage:
#   bash scripts/stream_from_ipcam.sh [IP] [PORT]
#
# Defaults: IP=192.168.8.176  PORT=5600
# =============================================================================

set -euo pipefail

CAM_HOST="${1:-192.168.8.176}"
CAM_PORT="${2:-8080}"
RTP_PORT="${3:-5600}"

CAM_URL="http://${CAM_HOST}:${CAM_PORT}/video?type=mp4"
RTP_DST="rtp://127.0.0.1:${RTP_PORT}"

echo "================================================================"
echo " IP Webcam → RTP relay"
echo "  Source : ${CAM_URL}"
echo "  Dest   : ${RTP_DST} (UDP)"
echo "================================================================"
echo " Make sure hm30_rtp_receiver is already running on port ${RTP_PORT}"
echo "================================================================"

exec ffmpeg \
    -fflags nobuffer \
    -flags low_delay \
    -i "${CAM_URL}" \
    -c:v libx264 \
    -preset ultrafast \
    -tune zerolatency \
    -pix_fmt yuv420p \
    -an \
    -f rtp \
    "${RTP_DST}"
