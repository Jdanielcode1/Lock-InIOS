---
allowed-tools: Bash(xcrun:*), Bash(xcodebuild:*), Bash(open:*)
description: Build and run the app on iPhone 17 simulator
---

Boot the iPhone 17 simulator and run the LockIn app on it:

1. First boot the iPhone 17 simulator:
!`xcrun simctl boot "iPhone 17" 2>&1 || true`

2. Open the Simulator app:
!`open -a Simulator`

3. Build and run the app on the simulator:
!`xcodebuild -scheme LockIn -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/ build 2>&1 | tail -20`

4. Install and launch the app on the simulator:
!`xcrun simctl install "iPhone 17" build/Build/Products/Debug-iphonesimulator/LockIn.app 2>&1 || echo "Install step - app may already be running"`
!`xcrun simctl launch "iPhone 17" com.lockin.LockIn 2>&1 || echo "Launch attempted"`

Summarize the build results and let me know if the app launched successfully.
