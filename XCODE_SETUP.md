# Xcode Setup Instructions

## Add Convex Swift Package

1. Open `LockIn.xcodeproj` in Xcode
2. Select your project in the navigator
3. Navigate to the **Package Dependencies** tab
4. Click the **+** button
5. Paste this URL: `https://github.com/get-convex/convex-swift`
6. Click **Add Package**
7. Select your target (LockIn) and click **Add Package**

## Add File References

After adding the package, you'll need to add the Swift files I've created to your Xcode project:

1. In Xcode, right-click on the **LockIn** folder in the navigator
2. Select **Add Files to "LockIn"...**
3. Navigate to and add these folders:
   - `LockIn/Models/` (contains Goal.swift, Subtask.swift, StudySession.swift)
   - `LockIn/Services/` (will contain ConvexService.swift, VideoService.swift)
   - `LockIn/ViewModels/` (will contain view models)
   - `LockIn/Views/` (will contain all view files)
   - `LockIn/Theme/` (will contain AppTheme.swift)

4. Make sure to check **"Copy items if needed"** and select your target

## Update Info.plist

Add camera and photo library permissions:

1. Select **Info.plist** in your project
2. Add these keys:
   - **Privacy - Camera Usage Description**: "We need access to your camera to record study session time-lapses"
   - **Privacy - Photo Library Usage Description**: "We need access to your photo library to save and import study videos"
   - **Privacy - Microphone Usage Description**: "We need access to your microphone for study session videos"

## Next Steps

After completing these steps, you'll need to:
1. Deploy your Convex backend (`npx convex dev` in the terminal)
2. Update the deployment URL in `ConvexService.swift`
3. Build and run the app!
