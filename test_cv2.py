import cv2
import os
os.environ["OPENCV_FFMPEG_CAPTURE_OPTIONS"] = "protocol_whitelist;file,udp,rtp|fflags;nobuffer|flags;low_delay"
cap = cv2.VideoCapture("stream.sdp", cv2.CAP_FFMPEG)
if not cap.isOpened():
    print("Failed to open stream")
else:
    ret, frame = cap.read()
    print("Read frame:", ret, frame.shape if frame is not None else None)
