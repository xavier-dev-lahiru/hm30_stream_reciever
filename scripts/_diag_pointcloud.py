#!/usr/bin/env python3
"""Quick diagnostic: print XYZ statistics of the next PointCloud2 message."""
import sys, os
sys.path.insert(0, '/home/lahiru_s/Documents/SLAM3R')

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import PointCloud2
import numpy as np
import struct

class DiagNode(Node):
    def __init__(self):
        super().__init__('pcd_diag')
        self.sub = self.create_subscription(PointCloud2, '/hm30/pointcloud', self.cb, 1)
        self.done = False

    def cb(self, msg):
        if self.done:
            return
        self.done = True
        N = msg.width
        raw = np.frombuffer(bytes(msg.data), dtype=np.float32).reshape(N, 4)
        x, y, z = raw[:,0], raw[:,1], raw[:,2]
        print(f"Points: {N}")
        print(f"X: min={x.min():.3f}  max={x.max():.3f}  mean={x.mean():.3f}")
        print(f"Y: min={y.min():.3f}  max={y.max():.3f}  mean={y.mean():.3f}")
        print(f"Z: min={z.min():.3f}  max={z.max():.3f}  mean={z.mean():.3f}")
        nan_count = int(np.isnan(raw[:,:3]).any(axis=1).sum())
        inf_count = int(np.isinf(raw[:,:3]).any(axis=1).sum())
        print(f"NaN pts: {nan_count}  Inf pts: {inf_count}")
        frame = msg.header.frame_id
        print(f"frame_id: {frame}")
        rclpy.shutdown()

def main():
    rclpy.init()
    node = DiagNode()
    print("Waiting for a /hm30/pointcloud message...")
    while rclpy.ok() and not node.done:
        rclpy.spin_once(node, timeout_sec=1.0)
    node.destroy_node()

if __name__ == '__main__':
    main()
