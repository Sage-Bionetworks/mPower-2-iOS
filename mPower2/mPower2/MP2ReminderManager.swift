//
//  MP2ReminderManager.swift
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
import DataTracking
import UserNotifications

class MP2ReminderManager : SBAMedicationReminderManager {
    
    override func notificationCategories() -> Set<UNNotificationCategory> {
        var categories = super.notificationCategories()
        let category = UNNotificationCategory(identifier: StudyBurstScheduleManager.shared.notificationCategory,
                                              actions: [], intentIdentifiers: [], options: [])
        categories.insert(category)
        return categories
    }
    
    override func instantiateTaskViewModel(for taskInfo: RSDTaskInfo, in activityGroup: SBAActivityGroup? = nil) -> (taskViewModel: RSDTaskViewModel, referenceSchedule: SBBScheduledActivity?) {
        
        if taskInfo.identifier == RSDIdentifier.medicationTask.identifier {
            do {
                let medsTask: RSDTask = try self.task(with: .medicationTask)
                let remindersTask = try SBAMedicationReminderTask(mainTask: medsTask)
                return self.instantiateTaskViewModel(for: remindersTask, in: activityGroup)
            }
            catch let err {
                assertionFailure("Failed to get the meds task. \(err)")
            }
        }
        
        // fall through to default.
        return super.instantiateTaskViewModel(for: taskInfo, in: activityGroup)
    }
}
