#include "ros2_publisher_node.h"

#include <iostream>

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

Ros2PublisherNode::Ros2PublisherNode(const rclcpp::NodeOptions& options)
    : Node("hm30_ros2_publisher", options)
{
    // -- Declare and read parameters -----------------------------------------
    this->declare_parameter<int>("port",  5600);
    this->declare_parameter<std::string>("topic", "/hm30/image_raw");
    this->declare_parameter<std::string>("sdp",   "stream.sdp");
    this->declare_parameter<int>("qos",   10);
    this->declare_parameter<std::string>("frame_id", "hm30_camera");

    const int         port     = this->get_parameter("port").as_int();
    const std::string topic    = this->get_parameter("topic").as_string();
    const std::string sdpPath  = this->get_parameter("sdp").as_string();
    const int         qosDepth = this->get_parameter("qos").as_int();
    m_frame_id                 = this->get_parameter("frame_id").as_string();

    RCLCPP_INFO(this->get_logger(),
                "HM30 ROS2 Publisher starting — port=%d  topic=%s  sdp=%s",
                port, topic.c_str(), sdpPath.c_str());

    // -- Publisher ------------------------------------------------------------
    m_pub = this->create_publisher<sensor_msgs::msg::Image>(topic, qosDepth);

    // -- HeadlessDecoder ------------------------------------------------------
    m_decoder = std::make_unique<HeadlessDecoder>(port, sdpPath);

    m_decoder->setConnectionCallback(
        [this](bool connected) { this->onConnection(connected); });

    m_decoder->setFrameCallback(
        [this](int w, int h, const uint8_t* rgb, size_t sz) {
            this->onFrame(w, h, rgb, sz);
        });

    m_decoder->start();

    // Start background publish thread
    m_pubThread = std::thread(&Ros2PublisherNode::runPublishLoop, this);

    RCLCPP_INFO(this->get_logger(), "Decoder and publisher threads started — waiting for stream...");
}

// ---------------------------------------------------------------------------
// Destruction
// ---------------------------------------------------------------------------

Ros2PublisherNode::~Ros2PublisherNode() {
    if (m_decoder) {
        RCLCPP_INFO(this->get_logger(), "Stopping decoder...");
        m_decoder->stop();
    }
    
    // Stop background thread
    m_running.store(false);
    m_queueCv.notify_all();
    if (m_pubThread.joinable()) {
        m_pubThread.join();
    }
}

// ---------------------------------------------------------------------------
// Frame callback (called from HeadlessDecoder worker thread)
// ---------------------------------------------------------------------------

void Ros2PublisherNode::onFrame(int width, int height,
                                const uint8_t* rgb, size_t size)
{
    auto msg = std::make_unique<sensor_msgs::msg::Image>();

    msg->header.stamp    = this->now();
    msg->header.frame_id = m_frame_id;
    msg->width           = static_cast<uint32_t>(width);
    msg->height          = static_cast<uint32_t>(height);
    msg->encoding        = "rgb8";
    msg->is_bigendian    = false;
    msg->step            = static_cast<uint32_t>(width * 3); // bytes per row

    // Copy pixel data into the message buffer.
    msg->data.assign(rgb, rgb + size);

    // Push to queue and notify publisher thread
    {
        std::lock_guard<std::mutex> lock(m_queueMutex);
        // If queue gets too large (e.g. publisher blocked for > 10 frames), drop oldest
        if (m_msgQueue.size() > 10) {
            m_msgQueue.pop();
        }
        m_msgQueue.push(std::move(msg));
    }
    m_queueCv.notify_one();
}

// ---------------------------------------------------------------------------
// Background Publish Loop
// ---------------------------------------------------------------------------

void Ros2PublisherNode::runPublishLoop()
{
    while (m_running.load()) {
        std::unique_ptr<sensor_msgs::msg::Image> msg;
        {
            std::unique_lock<std::mutex> lock(m_queueMutex);
            m_queueCv.wait(lock, [this]() {
                return !m_msgQueue.empty() || !m_running.load();
            });

            if (!m_running.load() && m_msgQueue.empty()) {
                break;
            }

            msg = std::move(m_msgQueue.front());
            m_msgQueue.pop();
        }

        if (msg) {
            m_pub->publish(std::move(msg));
        }
    }
}

// ---------------------------------------------------------------------------
// Connection callback (called from HeadlessDecoder worker thread)
// ---------------------------------------------------------------------------

void Ros2PublisherNode::onConnection(bool connected) {
    if (connected) {
        RCLCPP_INFO(this->get_logger(), "Stream CONNECTED — publishing frames.");
    } else {
        RCLCPP_WARN(this->get_logger(), "Stream DISCONNECTED — reconnecting...");
    }
}
