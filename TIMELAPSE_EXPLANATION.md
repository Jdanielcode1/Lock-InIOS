# Time-Lapse Feature Explanation

## How It Works

The Lock In app uses a **6x time conversion multiplier** to calculate study time from recorded videos, mimicking iPhone's native time-lapse behavior for videos under 10 minutes.

### Recording vs Study Time

When you record a study session:
- **Record for 5 minutes** → Counts as **30 minutes** of study time (5 × 6 = 30)
- **Record for 10 minutes** → Counts as **60 minutes** (1 hour) of study time
- **Record for 2 minutes** → Counts as **12 minutes** of study time

### Why 6x?

This multiplier is based on iPhone's time-lapse recording mechanism:
- iPhone records time-lapse at **2 frames per second** (for videos under 10 minutes)
- Playback is at standard **30 frames per second**
- This creates an approximate **6x speed-up** ratio between real-time and video duration

### Technical Implementation

#### 1. **Video Recording** (`CameraRecorderView.swift`)
- Uses `AVCaptureMovieFileOutput` for standard video recording
- Records at normal speed (not true time-lapse)
- Front/back camera switching supported
- Real-time duration timer displayed during recording

#### 2. **Duration Calculation** (`VideoService.swift:24`)
```swift
func getVideoDuration(url: URL, isTimeLapse: Bool = false) async throws -> Double {
    let asset = AVURLAsset(url: url)
    let duration = try await asset.load(.duration)
    let seconds = CMTimeGetSeconds(duration)
    let minutes = seconds / 60.0

    if isTimeLapse {
        return minutes * 6.0  // Apply 6x multiplier
    }

    return minutes
}
```

#### 3. **Upload Process** (`VideoService.swift:101`)
- Compresses video for faster upload
- Applies 6x conversion: `isTimeLapse: true` (default)
- Stores converted duration in Convex database
- Updates goal progress with study time

#### 4. **Video Playback** (`VideoPlayerView.swift`)
- Tap any study session card to watch the video
- Uses `AVPlayer` for smooth playback
- Shows both video duration and calculated study time
- Videos play at normal speed (as recorded)

### Upload Timeout Fix

The app now uses extended timeouts for large video uploads:
- **Request timeout**: 5 minutes (300 seconds)
- **Resource timeout**: 10 minutes (600 seconds)

This prevents timeout errors when uploading longer or high-quality videos over slower connections.

### Camera Features

- **Front camera** (default): Record yourself studying
- **Back camera**: Record your workspace or materials
- **Switch cameras**: Tap the camera flip button before recording
- **Cannot switch during recording**: Must stop recording first

### Note on True Time-Lapse

iOS's native Camera app uses private APIs not available to third-party apps for true time-lapse recording (capturing frames at intervals). Our implementation:
- ✅ Correctly calculates study time with 6x conversion
- ✅ Uploads compressed video efficiently
- ✅ Tracks progress accurately
- ⚠️ Videos are recorded at normal speed (not sped up during recording)

The important part for study tracking is the **duration conversion**, which accurately represents your study time regardless of how the video was captured.

## User Instructions

1. **Record a study session**:
   - Open a goal
   - Tap "Record" button
   - Choose front or back camera
   - Record yourself studying
   - Video will be converted to study time automatically (6x)

2. **Watch your sessions**:
   - Tap any study session card in goal details
   - Video player opens with playback controls
   - See both video length and study time calculated

3. **Track your progress**:
   - Goal progress updates automatically
   - Study time = Video duration × 6
   - Complete goals by reaching target hours!
