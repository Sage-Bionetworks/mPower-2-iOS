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

import ResearchV2UI
import WebKit
import ResearchV2
import BridgeSDK
import BridgeApp

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

class ConsentViewController: RSDWebViewController, WKScriptMessageHandler {
    static let consentControllerName = "consentHandler"
    
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
        contentController.add(self, name: ConsentViewController.consentControllerName)
        configuration.userContentController = contentController
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        return configuration
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == ConsentViewController.consentControllerName {
            guard let info = message.body as? [ String: SBBJSONValue ],
                    let name = info["name"] as? String,
                    let scopeString = info["scope"] as? String,
                    let scope = SharingScope(rawValue: scopeString)?.bridgeValue()
                else {
                    return
            }
            
            self.activityIndicator.startAnimating()
            BridgeSDK.consentManager.consentSignature(name, forSubpopulationGuid: BridgeSDK.bridgeInfo.studyIdentifier, birthdate: nil, signatureImage: nil, dataSharing: scope) { (response, error) in
                // TODO: emm 2018-05-18 in case of error, throw up a dialog and then stay on the page so they can try again
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
