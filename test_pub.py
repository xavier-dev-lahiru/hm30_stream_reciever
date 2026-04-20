import rclpy
from std_msgs.msg import String
rclpy.init()
node = rclpy.create_node('test_pub')
pub = node.create_publisher(String, 'test_topic', 10)
import time
while True:
    msg = String()
    msg.data = "hello"
    pub.publish(msg)
    rclpy.spin_once(node, timeout_sec=1.0)
