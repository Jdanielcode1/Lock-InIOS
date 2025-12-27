import { v } from "convex/values";
import { userMutation, userQuery } from "./auth";

// Mutation: Save study session with local video path
export const create = userMutation({
  args: {
    goalId: v.id("goals"),
    subtaskId: v.optional(v.id("subtasks")),
    localVideoPath: v.string(),
    localThumbnailPath: v.optional(v.string()),
    durationMinutes: v.float64(),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    // Verify goal ownership
    const goal = await ctx.db.get(args.goalId);
    if (!goal) throw new Error("Goal not found");
    if (goal.userId !== userId) throw new Error("Not authorized");

    // Create the study session
    const sessionId = await ctx.db.insert("studySessions", {
      userId,
      goalId: args.goalId,
      subtaskId: args.subtaskId,
      localVideoPath: args.localVideoPath,
      localThumbnailPath: args.localThumbnailPath,
      durationMinutes: args.durationMinutes,
      createdAt: Date.now(),
    });

    // Update goal progress (convert minutes to hours)
    const hoursToAdd = args.durationMinutes / 60;
    const newCompletedHours = goal.completedHours + hoursToAdd;
    const status = newCompletedHours >= goal.targetHours ? "completed" : goal.status;

    await ctx.db.patch(args.goalId, {
      completedHours: newCompletedHours,
      status,
    });

    // Update subtask progress if applicable
    if (args.subtaskId) {
      const subtask = await ctx.db.get(args.subtaskId);
      if (subtask && subtask.userId === userId) {
        await ctx.db.patch(args.subtaskId, {
          completedHours: subtask.completedHours + hoursToAdd,
        });
      }
    }

    return sessionId;
  },
});

// Query: List study sessions for a goal
export const listByGoal = userQuery({
  args: { goalId: v.id("goals") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    // Verify goal ownership
    const goal = await ctx.db.get(args.goalId);
    if (!goal) throw new Error("Goal not found");
    if (goal.userId !== userId) throw new Error("Not authorized");

    const sessions = await ctx.db
      .query("studySessions")
      .withIndex("by_goal", (q) => q.eq("goalId", args.goalId))
      .order("desc")
      .collect();
    return sessions;
  },
});

// Query: List study sessions for a subtask
export const listBySubtask = userQuery({
  args: { subtaskId: v.id("subtasks") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    // Verify subtask ownership
    const subtask = await ctx.db.get(args.subtaskId);
    if (!subtask) throw new Error("Subtask not found");
    if (subtask.userId !== userId) throw new Error("Not authorized");

    const sessions = await ctx.db
      .query("studySessions")
      .withIndex("by_subtask", (q) => q.eq("subtaskId", args.subtaskId))
      .order("desc")
      .collect();
    return sessions;
  },
});

// Query: List all study sessions for the current user (for stats)
export const listAll = userQuery({
  args: {},
  handler: async (ctx) => {
    const userId = ctx.identity.tokenIdentifier;

    const sessions = await ctx.db
      .query("studySessions")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .order("desc")
      .collect();
    return sessions;
  },
});

// Mutation: Delete a study session (local files deleted by iOS app)
export const remove = userMutation({
  args: { id: v.id("studySessions") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    const session = await ctx.db.get(args.id);
    if (!session) throw new Error("Study session not found");
    if (session.userId !== userId) throw new Error("Not authorized");

    // Note: Local video/thumbnail files are deleted by the iOS app

    // Update goal progress (subtract hours)
    const hoursToSubtract = session.durationMinutes / 60;
    const goal = await ctx.db.get(session.goalId);
    if (goal && goal.userId === userId) {
      await ctx.db.patch(session.goalId, {
        completedHours: Math.max(0, goal.completedHours - hoursToSubtract),
      });
    }

    // Update subtask progress if applicable
    if (session.subtaskId) {
      const subtask = await ctx.db.get(session.subtaskId);
      if (subtask && subtask.userId === userId) {
        await ctx.db.patch(session.subtaskId, {
          completedHours: Math.max(0, subtask.completedHours - hoursToSubtract),
        });
      }
    }

    // Delete the session
    await ctx.db.delete(args.id);
  },
});
