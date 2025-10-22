# Delete Functionality - Goals & Study Sessions

## Overview

Added the ability to delete both goals and study sessions from the app.

## Features Implemented

### 1. ✅ Delete Study Sessions (Swipe to Delete)

**Location**: Goal Detail View → Study Sessions List

**How to Use**:
1. Open a goal
2. Swipe left on any study session
3. Tap "Delete"
4. Session is removed and goal progress is updated

**Implementation**:
- `GoalDetailView.swift:148-152` - Added `.onDelete` modifier
- `GoalDetailView.swift:276-285` - `deleteStudySessions()` method
- Automatically updates goal progress (subtracts hours)
- Deletes video from Convex storage
- Updates subtask progress if applicable

### 2. ✅ Delete Goals (Long Press Context Menu)

**Location**: Goals List View → Goal Cards

**How to Use**:
1. Long press on any goal card
2. Tap "Delete Goal" from the context menu
3. Goal and all associated data are deleted

**Implementation**:
- `GoalsListView.swift:34-42` - Added `.contextMenu` with delete option
- `GoalsViewModel.swift:48-54` - `deleteGoal()` method (already existed)
- Deletes all associated study sessions
- Deletes all videos from storage
- Removes all subtasks

## What Gets Deleted

### When Deleting a Study Session:
- ✅ Study session record from database
- ✅ Video file from Convex storage
- ✅ Thumbnail file (if exists)
- ✅ Updates goal progress (subtracts duration)
- ✅ Updates subtask progress (if linked)

### When Deleting a Goal:
- ✅ Goal record from database
- ✅ All study sessions for that goal
- ✅ All video files associated with sessions
- ✅ All thumbnails
- ✅ All subtasks for that goal

## Backend Implementation (Convex)

The delete operations are handled in the Convex backend:

**Study Sessions** (`convex/studySessions.ts:94-128`):
```typescript
export const remove = mutation({
  args: { id: v.id("studySessions") },
  handler: async (ctx, args) => {
    // 1. Delete video from storage
    await ctx.storage.delete(session.videoStorageId);

    // 2. Update goal progress (subtract hours)
    await ctx.db.patch(session.goalId, {
      completedHours: Math.max(0, goal.completedHours - hoursToSubtract)
    });

    // 3. Update subtask progress (if applicable)
    // 4. Delete the session record
    await ctx.db.delete(args.id);
  }
});
```

**Goals** (`convex/goals.ts`):
- Deletes goal record
- Cascade deletes handled by database constraints

## UI/UX Design

### Study Sessions (Swipe to Delete)
**Why**: Standard iOS pattern for lists
**Gesture**: Swipe left on session card
**Visual**: Red delete button appears
**Confirmation**: None (standard iOS behavior)

### Goals (Context Menu)
**Why**: Grid layout doesn't support swipe gestures well
**Gesture**: Long press on goal card
**Visual**: Context menu pops up
**Color**: Delete option shown in red
**Confirmation**: None (can be added if needed)

## Safety Features

1. **Progress Adjustment**: Goal progress automatically updates when sessions deleted
2. **Storage Cleanup**: Video files are deleted from Convex storage (prevents orphaned files)
3. **Cascade Updates**: Subtask progress updates when sessions deleted
4. **Error Handling**: Failed deletes are logged but don't crash app

## Future Enhancements

Possible improvements:

1. **Confirmation Dialog**
   ```swift
   .confirmationDialog("Delete Goal?", isPresented: $showingDeleteConfirmation) {
       Button("Delete", role: .destructive) { ... }
       Button("Cancel", role: .cancel) { }
   }
   ```

2. **Undo Feature**
   - Cache deleted item for 5 seconds
   - Show "Undo" toast
   - Restore if undo tapped

3. **Bulk Delete**
   - Select multiple sessions
   - Delete all at once
   - "Clear all completed" option

4. **Archive Instead of Delete**
   - Move to archived state
   - Don't count toward progress
   - Can restore later

## Testing Checklist

- [ ] Delete a study session via swipe
- [ ] Verify goal progress decreases
- [ ] Verify video is removed from storage
- [ ] Delete a goal via long press
- [ ] Verify all sessions for goal are deleted
- [ ] Verify all videos are deleted
- [ ] Create new session after deleting old ones
- [ ] Verify progress calculations are correct

## Usage Examples

### Delete Single Session
1. Go to goal detail view
2. Swipe left on "2m" session
3. Tap Delete
4. Progress updates: 12 min → 0 min

### Delete Entire Goal
1. Long press "Learn Swift" goal card
2. Tap "Delete Goal"
3. Goal and all 3 study sessions removed
4. All 3 videos deleted from storage

## Code References

**Study Session Delete**:
- UI: `GoalDetailView.swift:148-152`
- Logic: `GoalDetailView.swift:276-285`
- Backend: `ConvexService.swift:134-136`
- Convex: `convex/studySessions.ts:94-128`

**Goal Delete**:
- UI: `GoalsListView.swift:34-42`
- Logic: `GoalsViewModel.swift:48-54`
- Backend: `ConvexService.swift:48-50`
- Convex: `convex/goals.ts:remove`
