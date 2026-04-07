#include <QApplication>
#include <QCommandLineParser>
#include <QCommandLineOption>
#include <QDateTime>
#include <QFile>
#include <QDebug>
#include <iostream>
#include <signal.h>

#include "src/core/app_config.h"
#include "src/ui/dashboard.h"

// ---------------------------------------------------------------------------
// Structured logging — installed as the global Qt message handler.
// Prints ISO-8601 timestamps so logs are trivially parseable (e.g. by systemd).
// ---------------------------------------------------------------------------
static void structuredLogHandler(QtMsgType type,
                                 const QMessageLogContext & /*ctx*/,
                                 const QString &msg)
{
    const QByteArray localMsg  = msg.toLocal8Bit();
    const QByteArray timeStamp =
        QDateTime::currentDateTime()
        .toString(Qt::ISODateWithMs).toLocal8Bit();
    const char *ts = timeStamp.constData();
    const char *m  = localMsg.constData();

    switch (type) {
    case QtDebugMsg:    fprintf(stdout, "[%s] [DEBUG] %s\n", ts, m); break;
    case QtInfoMsg:     fprintf(stdout, "[%s] [INFO]  %s\n", ts, m); break;
    case QtWarningMsg:  fprintf(stderr, "[%s] [WARN]  %s\n", ts, m); break;
    case QtCriticalMsg: fprintf(stderr, "[%s] [CRIT]  %s\n", ts, m); break;
    case QtFatalMsg:
        fprintf(stderr, "[%s] [FATAL] %s\n", ts, m);
        abort();
    }
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
int main(int argc, char *argv[])
{
    qInstallMessageHandler(structuredLogHandler);

    // Honour default SIGINT behaviour so Ctrl-C terminates the process.
    signal(SIGINT, SIG_DFL);

    QApplication app(argc, argv);
    app.setApplicationName(QLatin1String(AppConfig::kAppName));
    app.setApplicationVersion(QLatin1String(AppConfig::kAppVersion));

    qInfo() << "=== SIYI HM30 RTP Receiver" << AppConfig::kAppVersion << "===";

    // -- Command-line interface -----------------------------------------------
    QCommandLineParser parser;
    parser.setApplicationDescription(
        QStringLiteral("Production-grade H.264 RTP/UDP receiver and dashboard for the SIYI HM30."));
    parser.addHelpOption();
    parser.addVersionOption();

    const QCommandLineOption portOption(
        {QStringLiteral("p"), QStringLiteral("port")},
        QStringLiteral("UDP port to listen on (default: %1).").arg(AppConfig::kDefaultPort),
        QStringLiteral("port"),
        QString::number(AppConfig::kDefaultPort));
    parser.addOption(portOption);

    parser.process(app);

    bool ok = false;
    const int port = parser.value(portOption).toInt(&ok);
    if (!ok || port < AppConfig::kMinPort || port > AppConfig::kMaxPort) {
        qCritical() << "Invalid port specified. Must be in range"
                    << AppConfig::kMinPort << "-" << AppConfig::kMaxPort;
        return 1;
    }

    qInfo() << "Binding listener to UDP port" << port;

    // -- Stylesheet loading (embedded Qt resource → self-contained binary) ----
    QFile styleFile(QLatin1String(AppConfig::kStylesheetResource));
    if (styleFile.open(QFile::ReadOnly)) {
        app.setStyleSheet(QLatin1String(styleFile.readAll()));
        styleFile.close();
        qInfo() << "Stylesheet applied from Qt resource.";
    } else {
        qWarning() << "Failed to load stylesheet — dashboard may render unstyled.";
    }

    // -- Launch ---------------------------------------------------------------
    Dashboard dashboard(port);
    dashboard.show();

    return app.exec();
}
