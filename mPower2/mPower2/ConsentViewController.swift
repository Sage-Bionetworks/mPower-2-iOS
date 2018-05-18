//
//  ConsentViewController.swift
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

import ResearchUI
import WebKit
import Research
import BridgeSDK
import BridgeApp

struct ConsentInfo: Decodable {
    enum SharingScope: String, Codable {
        case no_sharing, sponsors_and_partners, all_qualified_researchers
        
        func bridgeValue() -> SBBParticipantDataSharingScope {
            switch self {
            case .no_sharing:
                return .none
            case .sponsors_and_partners:
                return .study
            case .all_qualified_researchers:
                return .all
            }
        }
    }
    
    let name: String
    let scope: SharingScope?
}

class ConsentViewController: RSDWebViewController, WKScriptMessageHandler {
    override func webViewConfiguration() -> WKWebViewConfiguration {
        let configuration = super.webViewConfiguration()
        let source = """
            function consentsToResearch(jsonBlob) {
                    try {
                        webkit.messageHandlers.consentHandler.postMessage(jsonBlob);
                    } catch(err) {
                        console.log('The native context does not exist yet');
                    }
            }
        """
        let consentsScript = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        let contentController = WKUserContentController()
        contentController.addUserScript(consentsScript)
        configuration.userContentController = contentController
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        return configuration
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "consentHandler" {
            let decoder = RSDFactory.shared.createJSONDecoder()
            guard let jsonBlob = message.body as? String,
                let jsonObj = jsonBlob.data(using: .utf8),
                let info = try? decoder.decode(ConsentInfo.self, from: jsonObj)
                else {
                    return
            }
            
            self.activityIndicator.startAnimating()
            BridgeSDK.consentManager.consentSignature(info.name, forSubpopulationGuid: BridgeSDK.bridgeInfo.studyIdentifier, birthdate: nil, signatureImage: nil, dataSharing: info.scope?.bridgeValue() ?? .none) { (response, error) in
                // transition to whatever the correct app state is at this point
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
                    appDelegate.showAppropriateViewController(animated: true)
                }
            }
        }
    }
}
