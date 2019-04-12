//
//  UIColor+mPowerTheme.swift
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

import Foundation
import ResearchUI

extension UIColor {

    // MARK: Severity
    
    //    None: Fill #E8FAE8, Stroke #C0EBC0
    //    232, 250, 232 and 192, 235, 192
    //
    //    Mild: Fill #FFF0D4, Stroke #FFE2AD
    //    255, 240, 212 and 255, 226, 173
    //
    //    Moderate: Fill #FFE8D6, Stroke #FACFAF
    //    255, 232, 214 and 250, 207, 175
    //
    //    Severe: Fill #FCE9E6, Stroke #FFC5BD
    //    252, 233, 230 and 255, 197, 189
    
    /// The fill colors for the severity toggle.
    @objc open class var severityFill: [UIColor] {
        return [
            UIColor(red: 232 / 255.0, green: 250.0 / 255.0, blue: 232.0 / 255.0, alpha: 1),
            UIColor(red: 255.0 / 255.0, green: 240.0 / 255.0, blue: 212.0 / 255.0, alpha: 1),
            UIColor(red: 255.0 / 255.0, green: 232.0 / 255.0, blue: 214.0 / 255.0, alpha: 1),
            UIColor(red: 252.0 / 255.0, green: 233.0 / 255.0, blue: 230.0 / 255.0, alpha: 1)
        ]
    }
    
    /// The stroke colors for the severity toggle.
    @objc open class var severityStroke: [UIColor] {
        return [
            UIColor(red: 192.0 / 255.0, green: 235.0 / 255.0, blue: 192.0 / 255.0, alpha: 1),
            UIColor(red: 255.0 / 255.0, green: 226.0 / 255.0, blue: 173.0 / 255.0, alpha: 1),
            UIColor(red: 250.0 / 255.0, green: 207.0 / 255.0, blue: 175.0 / 255.0, alpha: 1),
            UIColor(red: 255.0 / 255.0, green: 197.0 / 255.0, blue: 189.0 / 255.0, alpha: 1)
        ]
    }
}
