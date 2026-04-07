# Architecture — SIYI HM30 RTP Receiver

## Overview

The application is a single-process Qt5/C++17 desktop application composed of two threads: the **UI thread** (main) and a **decode worker thread** (QThread). All inter-thread data transfer uses Qt's queued signal/slot mechanism, guaranteeing thread safety without explicit locking on the consumer side.

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Hardware / Network Layer                                               │
│                                                                         │
│  DJI Osmo Action 5 Pro                                                  │
│       │  H.264 (raw)                                                    │
│       ▼                                                                 │
│  GStreamer pipeline (stream_to_siyi.sh)                                 │
│       │  RTP/UDP encapsulation                                          │
│       ▼                                                                 │
│  HM30 Air Unit (192.168.144.11)  ──[radio link]──►  HM30 Ground Unit   │
│                                                         │               │
│                                                    Ethernet             │
│                                                         │               │
│                                                    Host PC              │
└─────────────────────────────────────────────────────────────────────────┘
                                                         │
                            UDP packets on port 5600     │
                                                         ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  hm30_rtp_receiver Process                                              │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Worker Thread  (QThread / StreamDecoder)                        │   │
│  │                                                                  │   │
│  │  avformat_open_input (SDP/RTP demux)                             │   │
│  │       │  AVPacket (H.264 NAL units)                              │   │
│  │       ▼                                                          │   │
│  │  avcodec_send_packet → avcodec_receive_frame                     │   │
│  │       │  AVFrame (YUV420P)                                       │   │
│  │       ▼                                                          │   │
│  │  sws_scale  (YUV420P → RGB24)                                    │   │
│  │       │  Raw RGB pixels                                          │   │
│  │       ▼                                                          │   │
│  │  QImage::copy()  ──[ emit frameReady(QImage) ]──────────────┐   │   │
│  └─────────────────────────────────────────────────────────────│───┘   │
│                Qt Queued Connection (thread boundary)          │        │
│  ┌─────────────────────────────────────────────────────────────│───┐   │
│  │  UI Thread                                                  ▼   │   │
│  │                                                                  │   │
│  │  VideoWidget::updateFrame(QImage)                                │   │
│  │       │  schedules update()                                      │   │
│  │       ▼                                                          │   │
│  │  VideoWidget::paintEvent  →  QPainter::drawImage                 │   │
│  │                                                                  │   │
│  │  Dashboard::refreshStatus (QTimer @ 2 Hz)                        │   │
│  │       reads: StreamDecoder::fps() / width() / height()           │   │
│  │       (std::atomic — safe cross-thread reads)                    │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Class Diagram

```
                         ┌──────────────────┐
                         │   QApplication   │
                         └────────┬─────────┘
                                  │ owns
                         ┌────────▼─────────┐
                         │    Dashboard     │  QMainWindow
                         │  (UI Thread)     │
                         └──┬──────────┬────┘
                            │ owns     │ owns
              ┌─────────────▼──┐   ┌──▼──────────────┐
              │  VideoWidget   │   │  StreamDecoder   │  QThread
              │  (UI Thread)   │   │  (Worker Thread) │
              └────────────────┘   └──────────────────┘
                      ▲                    │
                      │   frameReady()     │  (queued signal)
                      └────────────────────┘
                      ▲                    │
                      │ connectionChanged()│  (queued signal)
                      └────────────────────┘
```

---

## Module Descriptions

### `src/core/app_config.h`
Header-only namespace containing all compile-time constants (ports, timeouts, FFmpeg tuning). No business logic.

### `src/core/StreamDecoder` (QThread)
Owns the full FFmpeg pipeline. Runs on a dedicated thread. Reconnects automatically on stream loss. Emits `frameReady(QImage)` and `connectionChanged(bool)` via queued signals. Thread-safe stat accessors (`fps()`, `videoWidth()`, `videoHeight()`) backed by `std::atomic`.

### `src/ui/VideoWidget` (QWidget)
Pure display primitive. Receives `QImage` frames, scales them aspect-ratio-correct, and renders via `QPainter`. Draws a checkerboard placeholder when disconnected. No decode logic.

### `src/ui/Dashboard` (QMainWindow)
Wires VideoWidget ↔ StreamDecoder, builds the two-column layout, and runs the 2 Hz status-refresh timer. All colour changes are driven by Qt dynamic properties (`active="true/false"`) so that QSS controls visual state without any C++ `setStyleSheet()` calls.

### `resources/style.qss`
Single source of truth for all visual styling. Embedded into the binary via Qt Resource System at build time. Uses `[active="true"]` / `[active="false"]` selectors for dynamic LED and status-label colours.

---

## Threading Model

| Thread       | Responsibility                          | Synchronization                         |
|:-------------|:----------------------------------------|:----------------------------------------|
| UI (main)    | Widget painting, event loop, timers     | Receives signals via Qt queued connection |
| Worker (QThread) | FFmpeg demux + decode + sws_scale | Emits signals; atomics for stat reads   |

**Back-buffer mutex**: `StreamDecoder::m_bufMutex` guards the single `QImage m_backBuf` used for in-place `sws_scale` writes. Immediately after conversion, `m_backBuf.copy()` is emitted — releasing the lock before the (potentially slow) signal delivery.

---

## Signal/Slot Connection Table

| Signal (emitter)                          | Slot (receiver)                              | Connection type |
|:------------------------------------------|:---------------------------------------------|:----------------|
| `StreamDecoder::frameReady(QImage)`       | `VideoWidget::updateFrame(QImage)`           | Auto (queued)   |
| `StreamDecoder::connectionChanged(bool)`  | `VideoWidget::setConnectionStatus(bool)`     | Auto (queued)   |
| `StreamDecoder::connectionChanged(bool)`  | `Dashboard::onConnectionChanged(bool)`       | Auto (queued)   |
| `QTimer::timeout()`                       | `Dashboard::refreshStatus()`                 | Auto (direct)   |
