#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <rclcpp/rclcpp.hpp>
#include <thread>
#include "RosBackend.h"
#include "VideoStreamItem.h"

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    // Initialize ROS 2
    rclcpp::init(argc, argv);
    auto node = std::make_shared<rclcpp::Node>("uav_control_ui_node");

    // Initialize Qt App
    QGuiApplication app(argc, argv);

    // Register Custom QML Types
    qmlRegisterType<VideoStreamItem>("CustomControls", 1, 0, "VideoStreamItem");

    RosBackend rosBackend;
    rosBackend.setNode(node);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("rosBackend", &rosBackend);

    const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    engine.load(url);

    // Spin ROS 2 in a separate thread
    std::thread rosThread([&node]() {
        rclcpp::spin(node);
    });

    int exitCode = app.exec();

    rclcpp::shutdown();
    if (rosThread.joinable()) {
        rosThread.join();
    }

    return exitCode;
}
