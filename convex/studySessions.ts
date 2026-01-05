import { v } from "convex/values";
import { paginationOptsValidator } from "convex/server";
import { action } from "./_generated/server";
import { userMutation, userQuery } from "./auth";

// Mutation: Save study session with local video path
export const create = userMutation({
  args: {
    goalId: v.id("goals"),
    goalTodoId: v.optional(v.id("goalTodos")),
    localVideoPath: v.string(),
    localThumbnailPath: v.optional(v.string()),
    durationMinutes: v.float64(),
    notes: v.optional(v.string()),
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
      goalTodoId: args.goalTodoId,
      localVideoPath: args.localVideoPath,
      localThumbnailPath: args.localThumbnailPath,
      durationMinutes: args.durationMinutes,
      notes: args.notes,
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

    // Update goal todo progress if applicable (for hours-based todos)
    if (args.goalTodoId) {
      const goalTodo = await ctx.db.get(args.goalTodoId);
      if (goalTodo && goalTodo.userId === userId && goalTodo.todoType === "hours") {
        const newCompletedHours = (goalTodo.completedHours || 0) + hoursToAdd;
        const isCompleted = goalTodo.estimatedHours ? newCompletedHours >= goalTodo.estimatedHours : false;
        await ctx.db.patch(args.goalTodoId, {
          completedHours: newCompletedHours,
          isCompleted,
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
    if (!goal || goal.userId !== userId) return [];

    const sessions = await ctx.db
      .query("studySessions")
      .withIndex("by_goal", (q) => q.eq("goalId", args.goalId))
      .order("desc")
      .collect();
    return sessions;
  },
});

// Query: List study sessions for a goal todo
export const listByGoalTodo = userQuery({
  args: { goalTodoId: v.id("goalTodos") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    // Verify goal todo ownership
    const goalTodo = await ctx.db.get(args.goalTodoId);
    if (!goalTodo || goalTodo.userId !== userId) return [];

    const sessions = await ctx.db
      .query("studySessions")
      .withIndex("by_goal_todo", (q) => q.eq("goalTodoId", args.goalTodoId))
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

// Query: List all study sessions with pagination (for timeline)
export const listAllPaginated = userQuery({
  args: { paginationOpts: paginationOptsValidator },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    return await ctx.db
      .query("studySessions")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .order("desc")
      .paginate(args.paginationOpts);
  },
});

// Query: List study sessions for a goal with pagination
export const listByGoalPaginated = userQuery({
  args: {
    goalId: v.id("goals"),
    paginationOpts: paginationOptsValidator,
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    // Verify goal ownership
    const goal = await ctx.db.get(args.goalId);
    if (!goal || goal.userId !== userId) return { page: [], isDone: true, continueCursor: null };

    return await ctx.db
      .query("studySessions")
      .withIndex("by_goal", (q) => q.eq("goalId", args.goalId))
      .order("desc")
      .paginate(args.paginationOpts);
  },
});

// Action wrapper for iOS (ConvexMobile doesn't have .query method)
export const fetchAllPaginated = action({
  args: {
    numItems: v.number(),
    cursor: v.optional(v.string()),
  },
  handler: async (ctx, args): Promise<{
    page: Array<{
      _id: string;
      goalId: string;
      localVideoPath: string;
      localThumbnailPath?: string;
      durationMinutes: number;
      notes?: string;
      createdAt: number;
    }>;
    continueCursor: string | null;
    isDone: boolean;
  }> => {
    const result = await ctx.runQuery(
      // @ts-ignore - internal API
      "studySessions:listAllPaginated" as any,
      { paginationOpts: { numItems: args.numItems, cursor: args.cursor ?? null } }
    );
    return {
      page: result.page.map((s: any) => ({
        _id: s._id,
        goalId: s.goalId,
        localVideoPath: s.localVideoPath,
        localThumbnailPath: s.localThumbnailPath,
        durationMinutes: s.durationMinutes,
        notes: s.notes,
        createdAt: s.createdAt,
      })),
      continueCursor: result.continueCursor,
      isDone: result.isDone,
    };
  },
});

// Action wrapper for iOS - fetch by goal
export const fetchByGoalPaginated = action({
  args: {
    goalId: v.id("goals"),
    numItems: v.number(),
    cursor: v.optional(v.string()),
  },
  handler: async (ctx, args): Promise<{
    page: Array<{
      _id: string;
      goalId: string;
      goalTodoId?: string;
      localVideoPath: string;
      localThumbnailPath?: string;
      durationMinutes: number;
      notes?: string;
      createdAt: number;
    }>;
    continueCursor: string | null;
    isDone: boolean;
  }> => {
    const result = await ctx.runQuery(
      // @ts-ignore - internal API
      "studySessions:listByGoalPaginated" as any,
      { goalId: args.goalId, paginationOpts: { numItems: args.numItems, cursor: args.cursor ?? null } }
    );
    return {
      page: result.page.map((s: any) => ({
        _id: s._id,
        goalId: s.goalId,
        goalTodoId: s.goalTodoId,
        localVideoPath: s.localVideoPath,
        localThumbnailPath: s.localThumbnailPath,
        durationMinutes: s.durationMinutes,
        notes: s.notes,
        createdAt: s.createdAt,
      })),
      continueCursor: result.continueCursor,
      isDone: result.isDone,
    };
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

    // Update goal todo progress if applicable (for hours-based todos)
    if (session.goalTodoId) {
      const goalTodo = await ctx.db.get(session.goalTodoId);
      if (goalTodo && goalTodo.userId === userId && goalTodo.todoType === "hours") {
        await ctx.db.patch(session.goalTodoId, {
          completedHours: Math.max(0, (goalTodo.completedHours || 0) - hoursToSubtract),
        });
      }
    }

    // Delete the session
    await ctx.db.delete(args.id);
  },
});

// Mutation: Update video path for a study session (for adding voiceover)
export const updateVideo = userMutation({
  args: {
    id: v.id("studySessions"),
    localVideoPath: v.string(),
    localThumbnailPath: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    const session = await ctx.db.get(args.id);
    if (!session) throw new Error("Study session not found");
    if (session.userId !== userId) throw new Error("Not authorized");

    // Update the video path (and thumbnail if provided)
    const updateFields: { localVideoPath: string; localThumbnailPath?: string } = {
      localVideoPath: args.localVideoPath,
    };

    if (args.localThumbnailPath !== undefined) {
      updateFields.localThumbnailPath = args.localThumbnailPath;
    }

    await ctx.db.patch(args.id, updateFields);
  },
});

// Mutation: Update notes for a study session
export const updateNotes = userMutation({
  args: {
    id: v.id("studySessions"),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    const session = await ctx.db.get(args.id);
    if (!session) throw new Error("Study session not found");
    if (session.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, { notes: args.notes });
  },
});
