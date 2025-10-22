# Convex Backend Setup

## Getting Started

1. **Deploy to Convex Cloud:**
   ```bash
   npx convex dev
   ```
   This will:
   - Prompt you to log in to Convex
   - Create a new project
   - Deploy your functions
   - Give you a deployment URL

2. **Get Your Deployment URL:**
   After running `npx convex dev`, you'll see output like:
   ```
   Deployment URL: https://your-project-name.convex.cloud
   ```
   Copy this URL - you'll need it for the iOS app.

3. **Update iOS App:**
   In your Swift code, update the ConvexClient initialization with your deployment URL:
   ```swift
   let convex = ConvexClient(deploymentUrl: "https://your-project-name.convex.cloud")
   ```

## Available Functions

### Goals
- `goals:list` - Get all goals
- `goals:get` - Get a specific goal
- `goals:create` - Create a new goal
- `goals:updateProgress` - Update goal progress
- `goals:updateStatus` - Update goal status
- `goals:remove` - Delete a goal

### Subtasks
- `subtasks:listByGoal` - Get all subtasks for a goal
- `subtasks:create` - Create a new subtask
- `subtasks:updateProgress` - Update subtask progress
- `subtasks:remove` - Delete a subtask

### Study Sessions
- `studySessions:generateUploadUrl` - Get URL for video upload
- `studySessions:create` - Save study session after upload
- `studySessions:listByGoal` - Get all sessions for a goal
- `studySessions:listBySubtask` - Get all sessions for a subtask
- `studySessions:getVideoUrl` - Get URL to view a video
- `studySessions:remove` - Delete a session

## Development

Keep `npx convex dev` running while developing - it will hot reload your functions as you make changes.
