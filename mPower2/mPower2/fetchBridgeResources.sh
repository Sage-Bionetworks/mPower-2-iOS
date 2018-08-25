#!/bin/sh

#  fetchBridgeResources.sh
#  mPower2
#
#  Created by Erin Mounts on 5/27/16.
#  Copyright © 2016-2018 Sage Bionetworks. All rights reserved.

BRIDGE_INFO=$(find ../../iOSPrivateProjectInfo/${PROJECT} -name BridgeInfo${RESOURCE_OVERRIDE_SUFFIX}-private.plist)
STUDY_IDENTIFIER=$(/usr/libexec/plistbuddy -c "print studyIdentifier" ${BRIDGE_INFO})
echo "Study identifier: ${STUDY_IDENTIFIER}"
CONSENT_HTML=$(find . -name consent${RESOURCE_OVERRIDE_SUFFIX}.html | grep Base.lproj)
curl http://docs.sagebridge.org/${STUDY_IDENTIFIER}/consent.html -o ${CONSENT_HTML}
