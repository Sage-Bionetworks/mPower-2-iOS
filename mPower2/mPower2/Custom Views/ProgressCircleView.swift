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
import ResearchV2UI

@IBDesignable class ProgressCircleView: UIView {
    
    private let kVerticalPad: CGFloat = 12.0
    private let strokeWidth: CGFloat = 4.0
    
    lazy private var progressRing : RSDCountdownDial = {
        let frame = self.bounds.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2)
        let ring = RSDCountdownDial(frame: frame)
        ring.dialWidth = strokeWidth
        ring.ringWidth = strokeWidth
        ring.backgroundColor = UIColor.clear
        ring.innerColor = UIColor.white
        ring.hasShadow = false
        ring.progressColor = RSDDesignSystem.shared.colorRules.palette.primary.normal.color
        dayLabel.textColor = RSDDesignSystem.shared.colorRules.palette.primary.veryDark.color
        dayCountLabel.textColor = RSDDesignSystem.shared.colorRules.palette.primary.veryDark.color
        insertSubview(ring, at: 0)
        ring.rsd_alignAllToSuperview(padding: strokeWidth / 2)
        return ring
    }()
    
    @IBInspectable public var progress: CGFloat {
        get {
            return progressRing.progress
        }
        set {
            progressRing.progress = newValue
        }
    }
    
    lazy var dayLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "HelveticaNeue-Bold", size: 12.0)
        label.textColor = RSDDesignSystem.shared.colorRules.palette.primary.veryDark.color
        label.textAlignment = .center
        label.text = Localization.localizedString("STUDY_BURST_DAY")
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
        label.textColor = RSDDesignSystem.shared.colorRules.palette.primary.veryDark.color
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
    
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        displayDay(count: 14)
        setNeedsDisplay()
    }

    public func displayDay(count: Int) {
        dayCountLabel.text = String(count)
        show(day: true, icon: false)
    }
    
    public func displayIcon(image: UIImage?) {
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
