import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

// Mutation: Save study session with local video path
export const create = mutation({
  args: {
    goalId: v.id("goals"),
    subtaskId: v.optional(v.id("subtasks")),
    localVideoPath: v.string(),
    localThumbnailPath: v.optional(v.string()),
    durationMinutes: v.float64(),
  },
  handler: async (ctx, args) => {
    // Create the study session
    const sessionId = await ctx.db.insert("studySessions", {
      goalId: args.goalId,
      subtaskId: args.subtaskId,
      localVideoPath: args.localVideoPath,
      localThumbnailPath: args.localThumbnailPath,
      durationMinutes: args.durationMinutes,
      createdAt: Date.now(),
    });

    // Update goal progress (convert minutes to hours)
    const hoursToAdd = args.durationMinutes / 60;
    const goal = await ctx.db.get(args.goalId);
    if (goal) {
      const newCompletedHours = goal.completedHours + hoursToAdd;
      const status = newCompletedHours >= goal.targetHours ? "completed" : goal.status;

      await ctx.db.patch(args.goalId, {
        completedHours: newCompletedHours,
        status,
      });
    }

    // Update subtask progress if applicable
    if (args.subtaskId) {
      const subtask = await ctx.db.get(args.subtaskId);
      if (subtask) {
        await ctx.db.patch(args.subtaskId, {
          completedHours: subtask.completedHours + hoursToAdd,
        });
      }
    }

    return sessionId;
  },
});

// Query: List study sessions for a goal
export const listByGoal = query({
  args: { goalId: v.id("goals") },
  handler: async (ctx, args) => {
    const sessions = await ctx.db
      .query("studySessions")
      .withIndex("by_goal", (q) => q.eq("goalId", args.goalId))
      .order("desc")
      .collect();
    return sessions;
  },
});

// Query: List study sessions for a subtask
export const listBySubtask = query({
  args: { subtaskId: v.id("subtasks") },
  handler: async (ctx, args) => {
    const sessions = await ctx.db
      .query("studySessions")
      .withIndex("by_subtask", (q) => q.eq("subtaskId", args.subtaskId))
      .order("desc")
      .collect();
    return sessions;
  },
});

// Mutation: Delete a study session (local files deleted by iOS app)
export const remove = mutation({
  args: { id: v.id("studySessions") },
  handler: async (ctx, args) => {
    const session = await ctx.db.get(args.id);
    if (!session) throw new Error("Study session not found");

    // Note: Local video/thumbnail files are deleted by the iOS app

    // Update goal progress (subtract hours)
    const hoursToSubtract = session.durationMinutes / 60;
    const goal = await ctx.db.get(session.goalId);
    if (goal) {
      await ctx.db.patch(session.goalId, {
        completedHours: Math.max(0, goal.completedHours - hoursToSubtract),
      });
    }

    // Update subtask progress if applicable
    if (session.subtaskId) {
      const subtask = await ctx.db.get(session.subtaskId);
      if (subtask) {
        await ctx.db.patch(session.subtaskId, {
          completedHours: Math.max(0, subtask.completedHours - hoursToSubtract),
        });
      }
    }

    // Delete the session
    await ctx.db.delete(args.id);
  },
});
