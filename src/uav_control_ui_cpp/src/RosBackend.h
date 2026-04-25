#ifndef ROS_BACKEND_H
#define ROS_BACKEND_H

#include <QObject>
#include <QString>
#include <QImage>
#include <rclcpp/rclcpp.hpp>
#include <sensor_msgs/msg/image.hpp>
#include <std_msgs/msg/string.hpp>
#include <std_msgs/msg/float32.hpp>
#include <geometry_msgs/msg/point.hpp>
#include <cognition_brain_interfaces/srv/drone_pad_control.hpp>

class RosBackend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(int speed READ speed NOTIFY speedChanged)
    Q_PROPERTY(int temperature READ temperature NOTIFY temperatureChanged)
    Q_PROPERTY(int battery READ battery NOTIFY batteryChanged)
    Q_PROPERTY(bool isAuto READ isAuto WRITE setIsAuto NOTIFY isAutoChanged)
    Q_PROPERTY(bool mappingEnabled READ mappingEnabled WRITE setMappingEnabled NOTIFY mappingEnabledChanged)
    
    Q_PROPERTY(double panX READ panX NOTIFY panXChanged)
    Q_PROPERTY(double tiltY READ tiltY NOTIFY tiltYChanged)
    Q_PROPERTY(double linearSpeed READ linearSpeed NOTIFY linearSpeedChanged)
    Q_PROPERTY(double angularSpeed READ angularSpeed NOTIFY angularSpeedChanged)
    Q_PROPERTY(QString padStatus READ padStatus NOTIFY padStatusChanged)
    Q_PROPERTY(bool mainCameraOn READ mainCameraOn WRITE setMainCameraOn NOTIFY mainCameraOnChanged)

public:
    explicit RosBackend(QObject *parent = nullptr);
    ~RosBackend();

    void setNode(std::shared_ptr<rclcpp::Node> node);

    bool connected() const { return m_connected; }
    int speed() const { return m_speed; }
    int temperature() const { return m_temperature; }
    int battery() const { return m_battery; }
    bool isAuto() const { return m_isAuto; }
    bool mappingEnabled() const { return m_mappingEnabled; }

    double panX() const { return m_panX; }
    double tiltY() const { return m_tiltY; }
    double linearSpeed() const { return m_linearSpeed; }
    double angularSpeed() const { return m_angularSpeed; }
    QString padStatus() const { return m_padStatus; }
    bool mainCameraOn() const { return m_mainCameraOn; }

public slots:
    void setIsAuto(bool isAuto);
    void setMappingEnabled(bool enabled);
    void setMainCameraOn(bool isOn);
    void updateLeftJoystick(double x, double y);
    void updateRightJoystick(double x, double y);
    void stopAction();
    void cameraAction();
    void targetAction();
    void gimbalHomeAction();
    void launchUAV();
    void cancelTakeoff();

signals:
    void newFrameReceived(const QImage &image);
    void connectedChanged();
    void speedChanged();
    void temperatureChanged();
    void batteryChanged();
    void isAutoChanged();
    void mappingEnabledChanged();
    void panXChanged();
    void tiltYChanged();
    void linearSpeedChanged();
    void angularSpeedChanged();
    void padStatusChanged();
    void mainCameraOnChanged();

private:
    std::shared_ptr<rclcpp::Node> m_node;
    bool m_connected = false;
    int m_speed = 0;
    int m_temperature = 0;
    int m_battery = 0;
    bool m_isAuto = true;
    bool m_mappingEnabled = false;

    // Joystick 2
    double m_linearSpeed = 0.0;
    double m_angularSpeed = 0.0;

    rclcpp::Subscription<sensor_msgs::msg::Image>::SharedPtr m_imageSub;
    void imageCallback(const sensor_msgs::msg::Image::SharedPtr msg);

    // Drone Pad
    QString m_padStatus = "closed";
    rclcpp::Client<cognition_brain_interfaces::srv::DronePadControl>::SharedPtr m_padClient;
    rclcpp::Subscription<std_msgs::msg::String>::SharedPtr m_padStatusSub;
    void padStatusCallback(const std_msgs::msg::String::SharedPtr msg);

    // Gimbal Control
    double m_panX = 2050; // DEFAULT_PAN
    double m_tiltY = -4000; // DEFAULT_TILT
    rclcpp::Publisher<geometry_msgs::msg::Point>::SharedPtr m_gimbalPosPub;
    rclcpp::Publisher<std_msgs::msg::String>::SharedPtr m_gimbalHomePub;

    // Camera Pulse
    bool m_mainCameraOn = false;
    rclcpp::Publisher<std_msgs::msg::Float32>::SharedPtr m_cameraPulsePub;
};

#endif // ROS_BACKEND_H
