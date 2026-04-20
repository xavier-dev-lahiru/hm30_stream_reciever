import rclpy
from std_msgs.msg import String
rclpy.init()
node = rclpy.create_node('test_sub')
def cb(msg):
    print("Received:", msg.data)
node.create_subscription(String, 'test_topic', cb, 10)
rclpy.spin(node)
