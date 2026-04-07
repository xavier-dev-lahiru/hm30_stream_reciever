# Building — SIYI HM30 RTP Receiver

## System Prerequisites

Tested on **Ubuntu 22.04 LTS** (Jammy). Equivalent packages exist on other Debian-based distros.

```bash
sudo apt install -y \
    build-essential \
    cmake \
    pkg-config \
    qtbase5-dev \
    libavformat-dev \
    libavcodec-dev \
    libswscale-dev \
    libavutil-dev
```

Minimum versions:
| Dependency | Minimum | Notes |
|:-----------|:--------|:------|
| CMake      | 3.19    |       |
| Qt         | 5.12    | Qt 5.15 recommended |
| FFmpeg     | 4.x     | libav* and libswscale |
| GCC / Clang | GCC 9 / Clang 10 | C++17 required |

---

## Release Build (recommended)

```bash
# From the project root:
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

Produces: `build/hm30_rtp_receiver`

---

## Debug Build (with AddressSanitizer + UBSan)

```bash
mkdir -p build_debug && cd build_debug
cmake .. -DCMAKE_BUILD_TYPE=Debug
make -j$(nproc)
```

> **Note**: ASan/UBSan are automatically enabled in Debug mode via the CMakeLists.txt flags.

---

## Running the Application

```bash
# Default — listen on UDP port 5600:
./build/hm30_rtp_receiver

# Custom port:
./build/hm30_rtp_receiver --port 5700
./build/hm30_rtp_receiver -p 5700

# Print version:
./build/hm30_rtp_receiver --version

# Print usage:
./build/hm30_rtp_receiver --help
```

---

## Starting the Stream (source device)

```bash
# 720p stream to HM30 Air unit IP, UDP port 5600:
./stream_to_siyi.sh 192.168.144.11 5600

# 1080p stream:
./stream_to_siyi.sh 192.168.144.11 5600 1080p
```

---

## Installing (optional)

```bash
cmake --install build --prefix /opt/hm30
# Binary at: /opt/hm30/bin/hm30_rtp_receiver
# SDP at:    /opt/hm30/share/hm30_rtp_receiver/stream.sdp
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|:--------|:------------|:----|
| Black screen, no signal | Stream not arriving | Verify GStreamer pipeline running; check firewall: `sudo ufw allow 5600/udp` |
| `SDP input format unavailable` | FFmpeg built without RTP support | Install `libavformat-dev` (full build) |
| Segfault in `avcodec` | Mismatched FFmpeg shared libs | Recompile or match system FFmpeg version |
| Window unstyled | QRC resource not compiled | Ensure `CMAKE_AUTORCC ON` and `resources.qrc` in `CMakeLists.txt` |
| High CPU usage | Too many decoder threads | Lower `AppConfig::kDecoderThreads` to 1 |
