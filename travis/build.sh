#!/bin/sh
set -ex
if [[ "$TRAVIS_PULL_REQUEST" != "false" ]]; then     # on pull requests
    echo "Run unit tests against mPower2TestApp w/o the pointer to a private repo."
    FASTLANE_EXPLICIT_OPEN_SIMULATOR=2 bundle exec fastlane test project:"mPower2/mPower2.xcodeproj" scheme:"mPower2TestApp"
elif [[ -z "$TRAVIS_TAG" && "$TRAVIS_BRANCH" == "master" ]]; then  # non-tag commits to master branch
    echo "Build on merge to master"
    git clone https://github.com/Sage-Bionetworks/iOSPrivateProjectInfo.git ../iOSPrivateProjectInfo
    FASTLANE_EXPLICIT_OPEN_SIMULATOR=2 bundle exec fastlane test project:"mPower2/mPower2.xcodeproj" scheme:"mPower2"
# temporarily disable archive build due to https://github.com/fastlane/fastlane/issues/13186
#    bundle exec fastlane ci_archive scheme:"mPower2" export_method:"app-store" project:"mPower2/mPower2.xcodeproj"
elif [[ -z "$TRAVIS_TAG" && "$TRAVIS_BRANCH" =~ ^stable-.* ]]; then # non-tag commits to stable branches
    echo "Build on stable branch"
    git clone https://github.com/Sage-Bionetworks/iOSPrivateProjectInfo.git ../iOSPrivateProjectInfo
    FASTLANE_EXPLICIT_OPEN_SIMULATOR=2 bundle exec fastlane test project:"mPower2/mPower2.xcodeproj" scheme:"mPower2"
# temporarily disable archive build due to https://github.com/fastlane/fastlane/issues/13186
#    bundle exec fastlane beta scheme:"mPower2" export_method:"app-store" project:"mPower2/mPower2.xcodeproj"
fi
exit $?
