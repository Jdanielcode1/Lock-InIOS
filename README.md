# Lock In - Video-Based Study Tracker

A playful iOS app for tracking study goals through time-lapse video uploads. Prove you're putting in the work by uploading study session videos that automatically convert into progress toward your goals!

## Features

- **Goal Creation**: Set study goals with target hours (e.g., "Learn Swift - 30 hours")
- **Video-Based Tracking**: Upload time-lapse videos of yourself studying
- **Automatic Progress**: Video duration automatically adds to your goal completion time
- **Subtasks**: Break down goals into smaller manageable tasks
- **Real-time Sync**: All data syncs in real-time via Convex backend
- **Playful UI**: Purple, yellow, and red color theme with smooth animations

## Tech Stack

- **Frontend**: SwiftUI (iOS)
- **Backend**: Convex (TypeScript)
- **Storage**: Convex File Storage (for videos)
- **Real-time Data**: Convex reactive queries

## Setup Instructions

### 1. Convex Backend Setup

```bash
# Install dependencies
npm install

# Deploy to Convex Cloud
npx convex dev
```

This will:
- Prompt you to log in to Convex
- Create a new project
- Deploy your functions
- Give you a deployment URL (e.g., `https://your-project.convex.cloud`)

**Important**: Copy your deployment URL!

### 2. iOS App Setup

#### Step 1: Add Convex Swift Package

1. Open `LockIn.xcodeproj` in Xcode
2. Select your project in the navigator
3. Go to **Package Dependencies** tab
4. Click **+** button
5. Paste: `https://github.com/get-convex/convex-swift`
6. Add to your target

#### Step 2: Add Project Files to Xcode

The Swift files have been created, but need to be added to your Xcode project:

1. Right-click on **LockIn** folder in Xcode
2. Select **Add Files to "LockIn"...**
3. Add these folders (make sure to check "Copy items if needed"):
   - `Models/` (Goal.swift, Subtask.swift, StudySession.swift)
   - `Services/` (ConvexService.swift, VideoService.swift)
   - `ViewModels/` (GoalsViewModel.swift)
   - `Views/` (GoalsListView.swift, CreateGoalView.swift, GoalDetailView.swift, VideoRecorderView.swift)
   - `Theme/` (AppTheme.swift)

#### Step 3: Update Deployment URL

Open `Services/ConvexService.swift` and replace the deployment URL:

```swift
private let convex = ConvexClient(deploymentUrl: "https://YOUR-ACTUAL-DEPLOYMENT.convex.cloud")
```

#### Step 4: Add Privacy Permissions

Add these keys to your `Info.plist`:

- **Privacy - Camera Usage Description**: "We need access to your camera to record study session time-lapses"
- **Privacy - Photo Library Usage Description**: "We need access to your photo library to save and import study videos"
- **Privacy - Microphone Usage Description**: "We need access to your microphone for study session videos"

### 3. Run the App

1. Select a simulator or device
2. Build and run (⌘R)
3. Create your first goal!
4. Upload a study video to track your progress

## Project Structure

```
LockIn/
├── convex/                  # Convex backend
│   ├── schema.ts           # Database schema
│   ├── goals.ts            # Goal mutations/queries
│   ├── subtasks.ts         # Subtask mutations/queries
│   └── studySessions.ts    # Video upload & session tracking
├── LockIn/                  # iOS app
│   ├── Models/             # Data models
│   ├── Services/           # Business logic
│   ├── ViewModels/         # View models
│   ├── Views/              # SwiftUI views
│   └── Theme/              # Color theme & styling
└── README.md
```

## How It Works

### Video Upload Flow

1. **Select Video**: Choose a time-lapse video from your library
2. **Process**: App extracts video duration
3. **Compress**: Video is compressed for faster upload
4. **Upload**: Video is uploaded to Convex File Storage
5. **Track Progress**: Duration automatically adds to your goal's completed hours
6. **Sync**: Changes sync in real-time to all devices

### Data Model

**Goals**
- Title, description, target hours
- Completed hours (auto-calculated from study sessions)
- Status: active, completed, or paused

**Study Sessions**
- Linked to a goal (and optionally a subtask)
- Video storage ID
- Duration in minutes
- Upload timestamp

**Subtasks** (Optional)
- Break down goals into smaller tasks
- Track individual completion

## Color Theme

The app uses a playful color palette:

- **Primary Purple**: `#8033CC` - Main brand color
- **Bright Yellow**: `#FFD900` - Success & energy
- **Playful Red**: `#FF4D66` - Accents & motivation

Progress indicators change color based on completion:
- 0-25%: Red (just started)
- 25-50%: Orange (making progress)
- 50-75%: Yellow (halfway there)
- 75-100%: Light purple (almost done)
- 100%: Purple (completed!)

## Development

### Running Convex Dev Server

Keep this running while developing:

```bash
npx convex dev
```

This enables hot reloading for your backend functions.

### Adding New Features

1. Add Convex functions in `convex/` directory
2. Update ConvexService.swift to call new functions
3. Update UI components as needed

## Troubleshooting

### "Cannot find ConvexClient in scope"

Make sure you've added the Convex Swift package via SPM and added all files to your Xcode target.

### "Upload failed"

- Check your Convex deployment is running (`npx convex dev`)
- Verify the deployment URL in ConvexService.swift
- Ensure video file is not corrupted

### Video compression issues

The app automatically compresses videos to medium quality. For very large videos (>500MB), this may take time. Consider recording at lower resolution.

## Future Enhancements

- [ ] In-app time-lapse video recording
- [ ] Social features (share progress, follow friends)
- [ ] Achievements and badges
- [ ] Weekly/monthly statistics
- [ ] Pomodoro timer integration
- [ ] Study streaks and reminders

## License

MIT

---

Built with SwiftUI and Convex. Lock in and achieve your goals!
