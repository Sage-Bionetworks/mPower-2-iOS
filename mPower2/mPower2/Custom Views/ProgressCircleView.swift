//
//  ProgressCircleView.swift
//  mPower2
//
//  Created by Josh Bruhin on 4/30/18.
//  Copyright © 2018 Sage Bionetworks. All rights reserved.
//

import UIKit

class ProgressCircleView: UIView {

    let progressShape = CAShapeLayer()
    let backgroundShape = CAShapeLayer()
    
    public var progress: Double = 30.0 {
        didSet {
            updateProgress()
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    fileprivate func commonInit() {
        layer.addSublayer(backgroundShape)
        layer.addSublayer(progressShape)
        updateProgress()
    }
    
//    - (void)layoutSubviews {
//    [super layoutSubviews]; //if you want superclass's behaviour...  (and lay outing of children)
//    // resize your layers based on the view's new frame
//    layer.frame = self.bounds;
//    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        progressShape.frame = bounds
        backgroundShape.frame = bounds
//        updateProgress()
    }
    
    func updateProgress() {
        
//        let animation = CABasicAnimation(keyPath: "strokeEnd")
//        animation.fromValue = progressShape.strokeEnd
//        animation.toValue = progress / 100.0
//        animation.duration = 2.5
//        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut);
        
        let shortestSide: CGFloat = min(self.frame.size.width, self.frame.size.height)
        let strokeWidth: CGFloat = 4.0
        let frame = CGRect(x: strokeWidth/2, y: strokeWidth/2, width: shortestSide - strokeWidth, height: shortestSide - strokeWidth)
        
        
        backgroundShape.frame = frame
        backgroundShape.position = center
        backgroundShape.path = UIBezierPath(ovalIn: frame).cgPath
        backgroundShape.strokeColor = UIColor.butterscotch500.cgColor
        backgroundShape.lineWidth = strokeWidth
        backgroundShape.fillColor = UIColor.white.cgColor
        
        progressShape.frame = frame
        progressShape.path = backgroundShape.path
        progressShape.position = backgroundShape.position
        progressShape.strokeColor = UIColor.royal500.cgColor
        progressShape.lineWidth = backgroundShape.lineWidth
        progressShape.fillColor = UIColor.clear.cgColor
        progressShape.strokeEnd = CGFloat(progress/100.0)
        
//        if isAnimated {
//            progressShape.add(animation, forKey: nil)
//        }
        
    }
}
