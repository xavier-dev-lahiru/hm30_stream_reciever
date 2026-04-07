#include "dashboard.h"
#include "video_widget.h"
#include "../core/stream_decoder.h"
#include "../core/app_config.h"

#include <QApplication>
#include <QCoreApplication>
#include <QFile>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QGroupBox>
#include <QStatusBar>
#include <QStyle>
#include <QDebug>

// ---------------------------------------------------------------------------
// Construction / destruction
// ---------------------------------------------------------------------------

Dashboard::Dashboard(int port, QWidget *parent)
    : QMainWindow(parent)
    , m_port(port)
{
    setWindowTitle(QStringLiteral("%1 (port %2)")
                   .arg(QLatin1String(AppConfig::kWindowTitle))
                   .arg(m_port));
    setMinimumSize(AppConfig::kMinWindowWidth, AppConfig::kMinWindowHeight);
    showMaximized();

    buildUI();

    // Resolve SDP file path: prefer the copy next to the binary, fall back one level up.
    QString sdpPath = QCoreApplication::applicationDirPath() + "/stream.sdp";
    if (!QFile::exists(sdpPath)) {
        sdpPath = QCoreApplication::applicationDirPath() + "/../stream.sdp";
    }

    // Instantiate and wire the decode worker.
    m_decoder = new StreamDecoder(m_port, sdpPath, this);
    connect(m_decoder, &StreamDecoder::frameReady,
            m_video,   &VideoWidget::updateFrame);
    connect(m_decoder, &StreamDecoder::connectionChanged,
            m_video,   &VideoWidget::setConnectionStatus);
    connect(m_decoder, &StreamDecoder::connectionChanged,
            this,      &Dashboard::onConnectionChanged);

    // 2 Hz status refresh.
    m_statusTimer = new QTimer(this);
    connect(m_statusTimer, &QTimer::timeout, this, &Dashboard::refreshStatus);
    m_statusTimer->start(AppConfig::kStatusIntervalMs);

    // Start the asynchronous decode pipeline.
    m_decoder->start();

    qInfo() << "[Dashboard] Initialized — listening on UDP port" << m_port;
}

Dashboard::~Dashboard()
{
    if (m_decoder) {
        m_decoder->stop();
    }
}

// ---------------------------------------------------------------------------
// Private: UI construction
// ---------------------------------------------------------------------------

void Dashboard::buildUI()
{
    QWidget *central = new QWidget(this);
    setCentralWidget(central);

    auto *mainLayout = new QHBoxLayout(central);
    mainLayout->setContentsMargins(12, 12, 12, 12);
    mainLayout->setSpacing(12);

    mainLayout->addWidget(buildVideoPanel(), /*stretch=*/3);
    mainLayout->addWidget(buildInfoPanel(),  /*stretch=*/1);

    statusBar()->showMessage(
        QStringLiteral("SIYI HM30 RTP Receiver — Listening on UDP port %1...").arg(m_port));
}

QWidget *Dashboard::buildVideoPanel()
{
    auto *container  = new QWidget;
    auto *layout     = new QVBoxLayout(container);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(8);

    // -- Header row: LED · status label · stretch · FPS --
    auto *header = new QHBoxLayout;

    m_videoLed = new QLabel(QStringLiteral("●"));
    m_videoLed->setObjectName(QStringLiteral("videoLed"));
    m_videoLed->setFixedWidth(36);
    setLabelActive(m_videoLed, false);

    m_videoStatusLabel = new QLabel(QStringLiteral("VIDEO — Waiting for RTP..."));
    m_videoStatusLabel->setObjectName(QStringLiteral("videoStatusLabel"));
    setLabelActive(m_videoStatusLabel, false);

    m_fpsLabel = new QLabel;
    m_fpsLabel->setObjectName(QStringLiteral("fpsLabel"));

    header->addWidget(m_videoLed);
    header->addWidget(m_videoStatusLabel);
    header->addStretch();
    header->addWidget(m_fpsLabel);

    m_video = new VideoWidget(this);
    m_video->setPortInfo(m_port);

    layout->addLayout(header);
    layout->addWidget(m_video);

    return container;
}

QWidget *Dashboard::buildInfoPanel()
{
    auto *panel  = new QWidget;
    panel->setMinimumWidth(AppConfig::kInfoPanelMinWidth);
    auto *layout = new QVBoxLayout(panel);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(10);

    // -- Connection status group --
    auto *connGroup  = new QGroupBox(QStringLiteral("⚡ CONNECTION STATUS"));
    auto *connLayout = new QVBoxLayout(connGroup);
    connLayout->setSpacing(8);
    m_connLabel = new QLabel(
        QStringLiteral("Video: Waiting for stream...\nMode: RTP/UDP Receiver\nPort: %1").arg(m_port));
    m_connLabel->setObjectName(QStringLiteral("connLabel"));
    m_connLabel->setWordWrap(true);
    connLayout->addWidget(m_connLabel);
    layout->addWidget(connGroup);

    // -- Performance info group --
    auto *perfGroup  = new QGroupBox(QStringLiteral("⚡ PERFORMANCE (C++)"));
    auto *perfLayout = new QVBoxLayout(perfGroup);
    perfLayout->setSpacing(8);
    auto *perfInfo = new QLabel(
        QStringLiteral("• Direct FFmpeg decode (no OpenCV)\n"
                        "• Raw RTP/UDP (no RTSP overhead)\n"
                        "• Asynchronous QThread decoupling\n"
                        "• Signal/Slot queued delivery\n"
                        "• QPainter direct render"));
    perfInfo->setObjectName(QStringLiteral("perfInfo"));
    perfInfo->setWordWrap(true);
    perfLayout->addWidget(perfInfo);
    layout->addWidget(perfGroup);

    // -- Stream info group --
    auto *streamGroup  = new QGroupBox(QStringLiteral("📡 STREAM INFO"));
    auto *streamLayout = new QVBoxLayout(streamGroup);
    streamLayout->setSpacing(8);
    auto *streamInfo = new QLabel(
        QStringLiteral("Mode: RTP/UDP Receiver\n"
                        "Listen Port: %1\n"
                        "Codec: H.264 (FFmpeg direct)\n"
                        "Source: DJI Osmo Action 5 Pro\n"
                        "Link: Camera → HM30 Air → HM30 Ground → PC").arg(m_port));
    streamInfo->setObjectName(QStringLiteral("streamInfo"));
    streamInfo->setWordWrap(true);
    streamLayout->addWidget(streamInfo);
    layout->addWidget(streamGroup);

    layout->addStretch();
    return panel;
}

// ---------------------------------------------------------------------------
// Private: dynamic property helper
// ---------------------------------------------------------------------------

void Dashboard::setLabelActive(QLabel *label, bool active)
{
    label->setProperty("active", active);
    // Force the QStyle to re-evaluate QSS rules for this widget.
    style()->unpolish(label);
    style()->polish(label);
    label->update();
}

// ---------------------------------------------------------------------------
// Private slots
// ---------------------------------------------------------------------------

void Dashboard::refreshStatus()
{
    if (!m_decoder) {
        return;
    }

    const int    w   = m_decoder->videoWidth();
    const int    h   = m_decoder->videoHeight();
    const double fps = m_decoder->fps();
    const bool   live = (w > 0 && h > 0);

    setLabelActive(m_videoLed,         live);
    setLabelActive(m_videoStatusLabel, live);

    if (live) {
        m_videoStatusLabel->setText(
            QStringLiteral("VIDEO — %1×%2 LIVE (RTP)").arg(w).arg(h));
        m_fpsLabel->setText(
            QStringLiteral("%1 FPS").arg(fps, 0, 'f', 1));
        m_connLabel->setText(
            QStringLiteral("Video: ✅ Connected (%1×%2)\nFPS: %3\n"
                            "Codec: H.264 (FFmpeg)\nTransport: RTP/UDP port %4")
            .arg(w).arg(h).arg(fps, 0, 'f', 1).arg(m_port));
        statusBar()->showMessage(
            QStringLiteral("VID:✓  |  %1×%2 @ %3 FPS  |  RTP/UDP port %4  |  Direct FFmpeg")
            .arg(w).arg(h).arg(fps, 0, 'f', 1).arg(m_port));
    } else {
        m_videoStatusLabel->setText(QStringLiteral("VIDEO — No Signal"));
        m_fpsLabel->clear();
        m_connLabel->setText(
            QStringLiteral("Video: ❌ No stream\nListening on UDP port %1...\nWaiting for RTP packets")
            .arg(m_port));
        statusBar()->showMessage(
            QStringLiteral("VID:✗  |  Listening on UDP port %1...").arg(m_port));
    }
}

void Dashboard::onConnectionChanged(bool connected)
{
    Q_UNUSED(connected)
    // Immediately refresh rather than waiting for the next timer tick.
    refreshStatus();
}
