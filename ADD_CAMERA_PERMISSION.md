# Add Camera Permission to Fix Crash

Your app is crashing because it needs camera permission declared in Info.plist.

## Quick Fix in Xcode:

1. **Open your project in Xcode**
2. **Select the "LockIn" target** (blue icon) in the navigator
3. **Go to the "Info" tab**
4. **Add these privacy keys** (hover over any row and click the `+` button):

### Required Permissions:

| Key | Value |
|-----|-------|
| **Privacy - Camera Usage Description** | "Record time-lapse videos of your study sessions to track your progress" |
| **Privacy - Microphone Usage Description** | "Record audio with your study session videos" |
| **Privacy - Photo Library Usage Description** | "Save and import study session videos" |

### Exact Steps:

1. Click any existing row in the Info tab
2. Hover and click the `+` that appears
3. Type: `Privacy - Camera Usage Description`
4. In the "Value" column, paste: `Record time-lapse videos of your study sessions to track your progress`
5. Repeat for Microphone and Photo Library

## Alternative: Using Info.plist file directly

If you prefer editing the raw plist file:

1. In Xcode, right-click on the "LockIn" folder
2. Select "New File..."
3. Choose "Property List"
4. Name it "Info.plist"
5. Add these keys:

```xml
<key>NSCameraUsageDescription</key>
<string>Record time-lapse videos of your study sessions to track your progress</string>
<key>NSMicrophoneUsageDescription</key>
<string>Record audio with your study session videos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Save and import study session videos</string>
```

## After Adding:

1. **Clean Build Folder**: Product → Clean Build Folder (Cmd+Shift+K)
2. **Rebuild**: Product → Build (Cmd+B)
3. **Run on device**: The app will now ask for camera permission on first use

The crash should be fixed! 📹✅
