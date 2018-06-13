//
//  StudyBurstCompletionViewController.swift
//  mPower2
//
//  Created by Josh Bruhin on 6/7/18.
//  Copyright © 2018 Sage Bionetworks. All rights reserved.
//

import UIKit
import BridgeApp

class StudyBurstCompletionViewController: UIViewController {

    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var navFooterView: RSDGenericNavigationFooterView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setupView() {
        
        // Populate the labels
        titleLabel.text = Localization.localizedString("STUDY_BURST_COMPLETION_TITLE")
        textLabel.text = Localization.localizedString("STUDY_BURST_COMPLETION_TEXT")
        detailLabel.text = Localization.localizedString("STUDY_BURST_COMPLETION_DETAIL")

        // Configure the next button
        navFooterView.nextButton?.addTarget(self, action: #selector(nextHit(sender:)), for: .touchUpInside)
    }
    
    // MARK: Actions
    @objc
    func nextHit(sender: Any) {
        // TODO: jbruhin 6-7-18 implement
    }

}
