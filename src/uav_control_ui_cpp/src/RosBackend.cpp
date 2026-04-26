#include "RosBackend.h"
#include <iostream>
#include <QJsonDocument>
#include <QJsonObject>
#include <geometry_msgs/msg/point.hpp>
#include <std_msgs/msg/float32.hpp>

RosBackend::RosBackend(QObject *parent) : QObject(parent)
{
    // Start with dummy values or connected=false if we want to show "Waiting for ROS connection..."
}

RosBackend::~RosBackend()
{
}

void RosBackend::setNode(std::shared_ptr<rclcpp::Node> node)
{
    m_node = node;
    if (m_node) {
        m_connected = true;
        emit connectedChanged();
        
        m_imageSub = m_node->create_subscription<sensor_msgs::msg::Image>(
            "/hm30/image_raw", 10,
            std::bind(&RosBackend::imageCallback, this, std::placeholders::_1));

        m_padStatusSub = m_node->create_subscription<std_msgs::msg::String>(
            "/drone_pad/status", 10,
            std::bind(&RosBackend::padStatusCallback, this, std::placeholders::_1));

        m_padClient = m_node->create_client<cognition_brain_interfaces::srv::DronePadControl>("/drone_pad_control");
        
        m_gimbalPosPub = m_node->create_publisher<geometry_msgs::msg::Point>("/ugv_gimbal/position", 10);
        m_gimbalHomePub = m_node->create_publisher<std_msgs::msg::String>("/ugv_gimbal/home", 10);
        
        m_cameraPulsePub = m_node->create_publisher<std_msgs::msg::Float32>("/main_camera_pulse", 10);
        
        m_cmdVelPub = m_node->create_publisher<geometry_msgs::msg::Twist>("/cmd_vel", 10);

        m_cmdVelTimer = new QTimer(this);
        connect(m_cmdVelTimer, &QTimer::timeout, this, &RosBackend::publishCmdVel);
        m_cmdVelTimer->start(100); // 10Hz continuous publish
    }
}

void RosBackend::padStatusCallback(const std_msgs::msg::String::SharedPtr msg)
{
    QString jsonStr = QString::fromStdString(msg->data);
    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
    if (doc.isNull() || !doc.isObject()) {
        std::cerr << "Failed to parse drone pad status JSON: " << msg->data << std::endl;
        return;
    }
    
    QJsonObject obj = doc.object();
    QString newStatus = obj["status"].toString();
    
    if (m_padStatus != newStatus) {
        m_padStatus = newStatus;
        emit padStatusChanged();
    }
}

void RosBackend::imageCallback(const sensor_msgs::msg::Image::SharedPtr msg)
{
    if (msg->encoding != "rgb8") {
        std::cerr << "Unsupported image encoding: " << msg->encoding << std::endl;
        return;
    }

    QImage image(msg->data.data(), msg->width, msg->height, msg->step, QImage::Format_RGB888);
    // The QImage uses the memory from msg, so we must clone it before the msg is destroyed
    emit newFrameReceived(image.copy());
}

void RosBackend::setIsAuto(bool isAuto)
{
    if (m_isAuto != isAuto) {
        m_isAuto = isAuto;
        emit isAutoChanged();
    }
}

void RosBackend::setMappingEnabled(bool enabled)
{
    if (m_mappingEnabled != enabled) {
        m_mappingEnabled = enabled;
        emit mappingEnabledChanged();
    }
}

void RosBackend::setMainCameraOn(bool isOn)
{
    if (m_mainCameraOn != isOn) {
        m_mainCameraOn = isOn;
        emit mainCameraOnChanged();
        
        if (m_cameraPulsePub) {
            auto msg = std_msgs::msg::Float32();
            msg.data = isOn ? 1.0f : 3.0f;
            m_cameraPulsePub->publish(msg);
            std::cout << "Published /main_camera_pulse: " << msg.data << std::endl;
        }
    }
}

void RosBackend::updateLeftJoystick(double x, double y)
{
    // Asymmetrical mapping for X (Pan)
    // Center is 2050. Min is 0, Max is 5100.
    if (x < 0) {
        m_panX = 2050 + (x * 2050); // -1 to 0 maps to 0 to 2050
    } else {
        m_panX = 2050 + (x * 3050); // 0 to 1 maps to 2050 to 5100
    }
    
    // Asymmetrical mapping for Y (Tilt)
    // Center is -4000. Range is -4100 to 0.
    // Inverted direction based on user feedback
    if (y < 0) {
        // Dragging UP (-1 to 0) maps to -4100 to -4000
        m_tiltY = -4000 + (y * 100); 
    } else {
        // Dragging DOWN (0 to 1) maps to -4000 to 0
        m_tiltY = -4000 + (y * 4000);
    }

    // Clamp values just to be perfectly safe
    if (m_panX < 0) m_panX = 0;
    if (m_panX > 5100) m_panX = 5100;
    if (m_tiltY < -4100) m_tiltY = -4100;
    if (m_tiltY > 0) m_tiltY = 0;

    emit panXChanged();
    emit tiltYChanged();
    
    std::cout << "Gimbal Joystick -> Pan: " << m_panX << ", Tilt: " << m_tiltY << std::endl;
    
    if (m_gimbalPosPub) {
        auto msg = geometry_msgs::msg::Point();
        msg.x = m_panX;
        msg.y = m_tiltY;
        msg.z = 0.0;
        m_gimbalPosPub->publish(msg);
    }
}

void RosBackend::setMaxSpeed(double speed)
{
    if (m_maxSpeed != speed) {
        m_maxSpeed = speed;
        emit maxSpeedChanged();
        
        // Re-apply current inputs with the new multiplier
        // This is especially necessary for keyboard inputs that don't trigger continuous events
        updateRightJoystick(m_rightJoyX, m_rightJoyY);
    }
}

void RosBackend::updateRightJoystick(double x, double y)
{
    m_rightJoyX = x;
    m_rightJoyY = y;

    // Linear / Angular speed mapping
    // x = angular (left/right), y = linear (forward/back)
    m_linearSpeed = -y * m_maxSpeed; // Up is -y in UI coordinates usually, so we invert
    m_angularSpeed = x * m_maxSpeed;

    emit linearSpeedChanged();
    emit angularSpeedChanged();
    
    // Immediate publish for responsiveness, timer will take over for continuous
    publishCmdVel();
}

void RosBackend::publishCmdVel()
{
    if (m_cmdVelPub && !m_isAuto) {
        auto twist = geometry_msgs::msg::Twist();
        twist.linear.x = m_linearSpeed;
        twist.angular.z = -m_angularSpeed; 
        m_cmdVelPub->publish(twist);
    }
}

void RosBackend::stopAction()
{
    std::cout << "STOP action triggered!" << std::endl;
    m_rightJoyX = 0.0;
    m_rightJoyY = 0.0;
    m_linearSpeed = 0.0;
    m_angularSpeed = 0.0;
    emit linearSpeedChanged();
    emit angularSpeedChanged();
    
    if (m_cmdVelPub) {
        auto twist = geometry_msgs::msg::Twist();
        m_cmdVelPub->publish(twist); // Immediate stop publish (ignoring isAuto check to force stop)
    }
}

void RosBackend::cameraAction()
{
    std::cout << "Camera action triggered!" << std::endl;
}

void RosBackend::targetAction()
{
    std::cout << "Target action triggered (Gimbal Default)!" << std::endl;
    m_panX = 2050;
    m_tiltY = -4000;
    emit panXChanged();
    emit tiltYChanged();

    if (m_gimbalHomePub) {
        auto msg = std_msgs::msg::String();
        msg.data = "default";
        m_gimbalHomePub->publish(msg);
    }
}

void RosBackend::gimbalHomeAction()
{
    std::cout << "Gimbal Home action triggered!" << std::endl;
    m_panX = 2050;
    m_tiltY = -4000;
    emit panXChanged();
    emit tiltYChanged();

    if (m_gimbalHomePub) {
        auto msg = std_msgs::msg::String();
        msg.data = "home";
        m_gimbalHomePub->publish(msg);
    }
}

void RosBackend::launchUAV()
{
    std::cout << "Launch UAV action triggered!" << std::endl;
    
    // Instantly update UI for responsiveness
    m_padStatus = "opening";
    emit padStatusChanged();
    
    if (!m_padClient) {
        std::cout << "Error: Pad client is null!" << std::endl;
        return;
    }

    auto request = std::make_shared<cognition_brain_interfaces::srv::DronePadControl::Request>();
    request->command = "open";

    std::cout << "Sending /drone_pad_control {command: 'open'} ..." << std::endl;

    m_padClient->async_send_request(request, [](rclcpp::Client<cognition_brain_interfaces::srv::DronePadControl>::SharedFuture future) {
        auto result = future.get();
        if (result->success) {
            std::cout << "Drone pad open command success: " << result->message << std::endl;
        } else {
            std::cout << "Drone pad open command failed: " << result->message << std::endl;
        }
    });
}

void RosBackend::cancelTakeoff()
{
    std::cout << "Cancel Takeoff action triggered!" << std::endl;

    // Instantly update UI for responsiveness
    m_padStatus = "closing";
    emit padStatusChanged();

    if (!m_padClient) {
        std::cout << "Error: Pad client is null!" << std::endl;
        return;
    }

    auto request = std::make_shared<cognition_brain_interfaces::srv::DronePadControl::Request>();
    request->command = "close";

    std::cout << "Sending /drone_pad_control {command: 'close'} ..." << std::endl;

    m_padClient->async_send_request(request, [](rclcpp::Client<cognition_brain_interfaces::srv::DronePadControl>::SharedFuture future) {
        auto result = future.get();
        if (result->success) {
            std::cout << "Drone pad close command success: " << result->message << std::endl;
        } else {
            std::cout << "Drone pad close command failed: " << result->message << std::endl;
        }
    });
}
