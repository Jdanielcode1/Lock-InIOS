# Quick Start Guide

Get Lock In running in 5 minutes!

## Step 1: Deploy Convex Backend (2 minutes)

```bash
# Make sure you're in the project directory
cd /Users/dcantu/Desktop/IOS_DEV/Lock-In-repo/LockIn

# Install dependencies (first time only)
npm install

# Start Convex dev server
npx convex dev
```

**What happens:**
1. You'll be prompted to log in to Convex (opens browser)
2. Choose "Create a new project"
3. Wait for deployment to complete
4. You'll see: `Deployment URL: https://your-project-name.convex.cloud`

**Copy this URL!** You'll need it in Step 3.

## Step 2: Configure Xcode (2 minutes)

1. **Open the project:**
   ```bash
   open LockIn.xcodeproj
   ```

2. **Add Convex Swift package:**
   - In Xcode, select the project in the navigator
   - Click the "Package Dependencies" tab
   - Click the `+` button
   - Enter: `https://github.com/get-convex/convex-swift`
   - Click "Add Package"
   - Select your target and click "Add Package"

3. **Add all Swift files to the project:**
   - Right-click on the "LockIn" folder (the one with the blue icon)
   - Select "Add Files to 'LockIn'..."
   - Select these folders:
     - `Models`
     - `Services`
     - `ViewModels`
     - `Views`
     - `Theme`
   - Make sure "Copy items if needed" is **checked**
   - Make sure "LockIn" target is **checked**
   - Click "Add"

4. **Add camera permissions:**
   - Click on "Info" in the project settings
   - Hover over any existing row and click the `+` that appears
   - Add these 3 keys:
     - `Privacy - Camera Usage Description` → "Record study sessions"
     - `Privacy - Photo Library Usage Description` → "Import study videos"
     - `Privacy - Microphone Usage Description` → "Record audio for videos"

## Step 3: Update Deployment URL (30 seconds)

1. In Xcode, open `Services/ConvexService.swift`
2. Find this line (around line 17):
   ```swift
   private let convex = ConvexClient(deploymentUrl: "https://your-deployment-name.convex.cloud")
   ```
3. Replace with YOUR deployment URL from Step 1
4. Save the file (⌘S)

## Step 4: Run the App! (30 seconds)

1. Select a simulator (iPhone 15 Pro recommended)
2. Click the Play button or press ⌘R
3. Wait for build to complete

## First Time Usage

1. **Create a Goal:**
   - Tap the `+` button
   - Enter: "Learn Swift" (or whatever you want)
   - Set target hours: 30
   - Tap "Create Goal"

2. **Add a Study Session:**
   - Tap on your goal card
   - Tap "Record Study Session"
   - Select a video from your library
   - Tap "Upload & Add to Goal"
   - Watch the magic happen!

## Troubleshooting

### Build errors about missing types?
- Make sure you added **all** the folders in Step 2.3
- Check that files are added to the "LockIn" target (not just the project)

### Can't import ConvexMobile?
- Make sure you added the Convex package in Step 2.2
- Try: Product → Clean Build Folder, then rebuild

### Upload fails?
- Make sure `npx convex dev` is still running in the terminal
- Check the deployment URL in ConvexService.swift matches your actual URL

### No videos to select?
- Simulator doesn't have videos! Use a real device, or:
- Record a quick video on your Mac and drag it into the simulator

## What's Next?

Now that it's running:

- Create multiple goals for different subjects
- Upload study videos to track your progress
- Watch the progress rings animate as you hit your targets
- Lock in and achieve your goals!

## Need Help?

Check the full README.md for detailed information about:
- Project structure
- How the video upload process works
- Adding new features
- Color theme customization

---

Happy studying! Remember: Lock in, upload proof, watch your progress grow! 🎯
