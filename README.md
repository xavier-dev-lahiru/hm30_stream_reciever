# SIYI HM30 — RTP H.264 Receiver Dashboard

A **production-grade**, low-latency C++17/Qt5 dashboard that receives and displays raw **RTP/UDP H.264** streams from a DJI Osmo Action 5 Pro via the SIYI HM30 datalink.

---

## Quick Start

```bash
# 1. Install dependencies
sudo apt install -y build-essential cmake pkg-config qtbase5-dev \
    libavformat-dev libavcodec-dev libswscale-dev libavutil-dev

# 2. Build
mkdir -p build && cd build && cmake .. -DCMAKE_BUILD_TYPE=Release && make -j$(nproc)

# 3. Run (default URL udp://0.0.0.0:5600)
./build/hm30_rtp_receiver
```

For a custom stream URL: `./build/hm30_rtp_receiver --url rtsp://192.168.144.25:8554/stream`

---

## Key Features

| Feature | Detail |
|:--------|:-------|
| **Transport** | Passive RTP/UDP listener (no RTSP handshake) |
| **Codec** | H.264 via FFmpeg direct — no OpenCV |
| **Threading** | Decoder on a dedicated QThread; UI never blocks |
| **Thread safety** | `std::atomic` stats; deep-copied QImage across signal boundary |
| **Styling** | 100% QSS-driven with dynamic properties — zero runtime `setStyleSheet()` |
| **Self-contained** | QSS embedded in binary via Qt Resource System |
| **Reconnection** | Automatic on stream loss with 100 ms back-off |
| **Latency** | Sub-frame (no RTSP overhead, `fflags=nobuffer`, `max_delay=0`) |

---

## Data Flow

```
DJI Osmo Action 5 Pro
    └─ H.264 ──► GStreamer (stream_to_siyi.sh)
                    └─ RTP/UDP ──► HM30 Air ──[radio]──► HM30 Ground
                                                              └─ Ethernet ──► This app (udp://0.0.0.0:5600)
                                                                                  ├─ FFmpeg decode ──► VideoWidget (Qt UI)
                                                                                  └─ Ros2Bridge ──────► ROS 2 Topic (/hm30/image_raw)
```

---

## Project Structure

```
hm_30_rtp_receiver/
├── CMakeLists.txt           Build system (CMake 3.19+)
├── main.cpp                 Entry point, CLI parsing, stylesheet loading
├── stream.sdp               RTP stream descriptor (port patched at runtime)
│
    ├── src/
    │   ├── core/
    │   │   ├── app_config.h     Compile-time constants
    │   │   ├── stream_decoder.h Async H.264 decode worker (QThread)
    │   │   └── stream_decoder.cpp
    │   ├── ros2/
    │   │   ├── ros2_bridge.h    ROS 2 image publisher (Optional, conditionally compiled)
    │   │   └── ros2_bridge.cpp
    │   └── ui/
    │       ├── dashboard.h      Main window
    │       ├── dashboard.cpp
    │       ├── video_widget.h   Pure display canvas (QPainter)
    │       └── video_widget.cpp
│
├── resources/
│   ├── resources.qrc        Qt resource bundle (embeds style.qss)
│   └── style.qss            Dark theme with dynamic-property selectors
│
├── cmake/
│   └── version.h.in         CMake version header template
│
└── docs/
    ├── ARCHITECTURE.md      Data flow, class diagram, threading model
    └── BUILDING.md          Prerequisites, build modes, install, troubleshooting
```

---

## CLI Options

```
Usage: hm30_rtp_receiver [options]

Options:
  -h, --help              Display help
  -v, --version           Display version
  -u, --url <url>         Stream URL to connect to (default: udp://0.0.0.0:5600)
  --headless              Run without the GUI (useful for ROS 2 background publisher)
```

---

## ROS 2 Integration

This application natively supports ROS 2. If ROS 2 is sourced before building, it will automatically compile the `Ros2Bridge` and publish frames to `/hm30/image_raw`.

```bash
# 1. Source ROS 2
source /opt/ros/humble/setup.bash

# 2. Build
cd build && cmake .. && make -j$(nproc)

# 3. Run Headless Publisher
./hm30_rtp_receiver --headless --url "udp://0.0.0.0:5600"
```

---

## Architecture Summary

The application uses a **two-thread model**:

- **UI thread** — Qt event loop, `VideoWidget` painting, dashboard status refresh (2 Hz)
- **Worker thread** (`StreamDecoder : QThread`) — FFmpeg demux → H.264 decode → YUV→RGB conversion → emit `frameReady(QImage)`

All cross-thread communication uses Qt's **queued signal/slot** mechanism. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full data-flow diagram and class relationships.

---

## Comparison: RTP vs RTSP

| Feature             | RTSP Dashboard         | **RTP Receiver (this)** |
|:--------------------|:-----------------------|:------------------------|
| Transport           | RTSP over UDP (client) | Raw RTP/UDP (passive)   |
| Stream initiation   | Client-pull            | Server-push             |
| Negotiation         | RTSP + auto SDP        | SDP file (manual)       |
| RTSP handshake cost | Yes                    | **None**                |
| Latency             | Low                    | **Lower**               |

---

## Building in Debug Mode (ASAN/UBSan)

```bash
mkdir -p build_debug && cd build_debug
cmake .. -DCMAKE_BUILD_TYPE=Debug
make -j$(nproc)
```

See [docs/BUILDING.md](docs/BUILDING.md) for full instructions.
