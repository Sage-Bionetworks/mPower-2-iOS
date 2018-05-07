//
//  ProgressCircleView.swift
//  mPower2
//
//  Copyright © 2018 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import UIKit

@IBDesignable class ProgressCircleView: UIView {
    
    private let kVerticalPad: CGFloat = 12.0

    let progressShape = CAShapeLayer()
    let backgroundShape = CAShapeLayer()
    
    @IBInspectable public var progress: Double = 30.0 {
        didSet {
            updateProgress()
        }
    }
    lazy var dayLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "HelveticaNeue-Bold", size: 12.0)
        label.textColor = UIColor.royal700
        label.textAlignment = .center
        label.text = "Day" // TODO: jbruhin 5-1-18 localize
        label.sizeToFit()
        addSubview(label)
        label.rsd_alignCenterHorizontal(padding: 0.0)
        label.rsd_alignToSuperview([.top], padding: kVerticalPad)
        return UILabel()
    }()
    lazy var dayCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "HelveticaNeue-Thin", size: 30.0)
        label.textColor = UIColor.royal700
        label.textAlignment = .center
        addSubview(label)
        label.rsd_alignCenterVertical(padding: 5.0)
        label.rsd_alignToSuperview([.leading, .trailing, .bottom], padding: 0.0)
        return label
    }()
    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        imageView.rsd_alignAllToSuperview(padding: 10.0)
        return UIImageView()
    }()


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
    
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        commonInit()
        displayDay(count: 14)
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        progressShape.frame = bounds
        backgroundShape.frame = bounds
    }
    
    func updateProgress() {
        
        let shortestSide: CGFloat = min(self.frame.size.width, self.frame.size.height)
        let strokeWidth: CGFloat = 4.0
        let frame = CGRect(x: strokeWidth/2, y: strokeWidth/2, width: shortestSide - strokeWidth, height: shortestSide - strokeWidth)
        
        backgroundShape.frame = frame
        backgroundShape.position = center
        backgroundShape.path = UIBezierPath(ovalIn: frame).cgPath
        backgroundShape.strokeColor = UIColor.rsd_dialRingBackground.cgColor
        backgroundShape.lineWidth = strokeWidth
        backgroundShape.fillColor = UIColor.white.cgColor
        
        progressShape.frame = frame
        progressShape.path = backgroundShape.path
        progressShape.position = backgroundShape.position
        progressShape.strokeColor = UIColor.rsd_dialRing.cgColor
        progressShape.lineWidth = backgroundShape.lineWidth
        progressShape.fillColor = UIColor.clear.cgColor
        progressShape.strokeEnd = CGFloat(progress/100.0)
    }
    
    public func displayDay(count: Int) {
        dayCountLabel.text = String(count)
        show(day: true, icon: false)
    }
    public func displayIcon(image: UIImage) {
        imageView.image = image
        show(day: false, icon: true)
    }
    public func displayEmpty() {
        show(day: false, icon: false)
    }
    private func show(day: Bool, icon: Bool) {
        dayLabel.isHidden = !day
        dayCountLabel.isHidden = !day
        imageView.isHidden = !icon
    }
}
