//
//  TimelineView.swift
//  OneCut
//
//  Created by zpc on 2018/8/28.
//  Copyright © 2018年 zpc. All rights reserved.
//

import UIKit

class TimelineView: UIView {
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        if true {
            // Position the white line layer of the timeMarker at the center of the red band layer
            let timeMarkerWhiteLineLayer = CAShapeLayer()
            timeMarkerWhiteLineLayer.frame = layer.bounds
            timeMarkerWhiteLineLayer.position = CGPoint(x:bounds.width/2, y:bounds.height/2)
            let space = bounds.height/8
            let whiteLinePath = CGPath(rect: CGRect(x: bounds.width/2-1, y: space, width: 2, height: bounds.height-space*2), transform: nil)
            timeMarkerWhiteLineLayer.fillColor = #colorLiteral(red: 0.9764705882, green: 0.4196078431, blue: 0.4, alpha: 1)
            timeMarkerWhiteLineLayer.path = whiteLinePath
            
            self.layer.addSublayer(timeMarkerWhiteLineLayer)
        }
    }
}
