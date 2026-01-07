import { v } from "convex/values";
import { userMutation, userQuery } from "./auth";
import { internalMutation } from "./_generated/server";

// Query: List all goal todos for a specific goal
export const listByGoal = userQuery({
  args: { goalId: v.id("goals") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    // Verify goal ownership
    const goal = await ctx.db.get(args.goalId);
    if (!goal || goal.userId !== userId) return [];

    const todos = await ctx.db
      .query("goalTodos")
      .withIndex("by_goal", (q) => q.eq("goalId", args.goalId))
      .order("desc")
      .collect();
    // Filter out archived todos
    return todos.filter((todo) => !todo.isArchived);
  },
});

// Query: List all goal todos for the current user (for todos tab)
export const listAll = userQuery({
  args: {},
  handler: async (ctx) => {
    const userId = ctx.identity.tokenIdentifier;

    const todos = await ctx.db
      .query("goalTodos")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .order("desc")
      .collect();

    // Filter out archived todos and get goal names
    const activeTodos = todos.filter((todo) => !todo.isArchived);
    const todosWithGoalNames = await Promise.all(
      activeTodos.map(async (todo) => {
        const goal = await ctx.db.get(todo.goalId);
        return {
          ...todo,
          goalTitle: goal?.title ?? "Unknown Goal",
        };
      })
    );

    return todosWithGoalNames;
  },
});

// Mutation: Create a new goal todo
export const create = userMutation({
  args: {
    goalId: v.id("goals"),
    title: v.string(),
    description: v.optional(v.string()),
    todoType: v.union(v.literal("simple"), v.literal("hours")),
    estimatedHours: v.optional(v.float64()),
    frequency: v.union(v.literal("none"), v.literal("daily"), v.literal("weekly")),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    // Verify goal ownership
    const goal = await ctx.db.get(args.goalId);
    if (!goal) throw new Error("Goal not found");
    if (goal.userId !== userId) throw new Error("Not authorized");

    const todoId = await ctx.db.insert("goalTodos", {
      userId,
      goalId: args.goalId,
      title: args.title,
      description: args.description,
      todoType: args.todoType,
      estimatedHours: args.todoType === "hours" ? args.estimatedHours : undefined,
      completedHours: args.todoType === "hours" ? 0 : undefined,
      isCompleted: false,
      frequency: args.frequency,
      createdAt: Date.now(),
    });
    return todoId;
  },
});

// Mutation: Toggle completion (for simple todos or manual toggle)
export const toggle = userMutation({
  args: {
    id: v.id("goalTodos"),
    isCompleted: v.boolean(),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (!todo) throw new Error("Goal todo not found");
    if (todo.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, {
      isCompleted: args.isCompleted,
    });
  },
});

// Mutation: Update hours progress (for hours-based todos)
export const updateProgress = userMutation({
  args: {
    id: v.id("goalTodos"),
    additionalHours: v.float64(),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (!todo) throw new Error("Goal todo not found");
    if (todo.userId !== userId) throw new Error("Not authorized");
    if (todo.todoType !== "hours") throw new Error("Cannot update hours on simple todo");

    const newCompletedHours = (todo.completedHours || 0) + args.additionalHours;
    const isCompleted = todo.estimatedHours ? newCompletedHours >= todo.estimatedHours : false;

    await ctx.db.patch(args.id, {
      completedHours: newCompletedHours,
      isCompleted,
    });

    return { completedHours: newCompletedHours, isCompleted };
  },
});

// Mutation: Attach video to goal todo
export const attachVideo = userMutation({
  args: {
    id: v.id("goalTodos"),
    localVideoPath: v.string(),
    localThumbnailPath: v.optional(v.string()),
    videoDurationMinutes: v.optional(v.float64()),
    videoNotes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (!todo) throw new Error("Goal todo not found");
    if (todo.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, {
      localVideoPath: args.localVideoPath,
      localThumbnailPath: args.localThumbnailPath,
      videoDurationMinutes: args.videoDurationMinutes,
      videoNotes: args.videoNotes,
    });
  },
});

// Mutation: Update video notes for a goal todo
export const updateVideoNotes = userMutation({
  args: {
    id: v.id("goalTodos"),
    videoNotes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (!todo) throw new Error("Goal todo not found");
    if (todo.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, { videoNotes: args.videoNotes });
  },
});

// Mutation: Delete a goal todo
export const remove = userMutation({
  args: { id: v.id("goalTodos") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (!todo) throw new Error("Goal todo not found");
    if (todo.userId !== userId) throw new Error("Not authorized");

    await ctx.db.delete(args.id);
  },
});

// Mutation: Remove video from a goal todo (keeps the todo, just removes video)
export const removeVideo = userMutation({
  args: { id: v.id("goalTodos") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (!todo) throw new Error("Goal todo not found");
    if (todo.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, {
      localVideoPath: undefined,
      localThumbnailPath: undefined,
      videoDurationMinutes: undefined,
      videoNotes: undefined,
    });
  },
});

// Mutation: Archive a goal todo
export const archive = userMutation({
  args: { id: v.id("goalTodos") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (!todo) throw new Error("Goal todo not found");
    if (todo.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, {
      isArchived: true,
    });
  },
});

// Mutation: Unarchive a goal todo
export const unarchive = userMutation({
  args: { id: v.id("goalTodos") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (!todo) throw new Error("Goal todo not found");
    if (todo.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, {
      isArchived: false,
    });
  },
});

// Mutation: Check and reset recurring todos for a goal (called on app launch/view appear)
export const checkAndResetRecurring = userMutation({
  args: { goalId: v.id("goals") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    // Verify goal ownership
    const goal = await ctx.db.get(args.goalId);
    if (!goal) throw new Error("Goal not found");
    if (goal.userId !== userId) throw new Error("Not authorized");

    const now = Date.now();

    const todos = await ctx.db
      .query("goalTodos")
      .withIndex("by_goal", (q) => q.eq("goalId", args.goalId))
      .collect();

    for (const todo of todos) {
      if (todo.frequency === "none") continue;

      const shouldReset = shouldResetTodo(todo.frequency, todo.lastResetAt || todo.createdAt, now);
      if (shouldReset) {
        await ctx.db.patch(todo._id, {
          isCompleted: false,
          lastResetAt: now,
          ...(todo.todoType === "hours" ? { completedHours: 0 } : {}),
        });
      }
    }
  },
});

// Internal mutation for cron job to reset all recurring todos
export const resetAllRecurringTodos = internalMutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();

    // Get all recurring todos
    const allTodos = await ctx.db.query("goalTodos").collect();
    const recurringTodos = allTodos.filter((t) => t.frequency !== "none");

    for (const todo of recurringTodos) {
      const shouldReset = shouldResetTodo(todo.frequency, todo.lastResetAt || todo.createdAt, now);
      if (shouldReset) {
        await ctx.db.patch(todo._id, {
          isCompleted: false,
          lastResetAt: now,
          ...(todo.todoType === "hours" ? { completedHours: 0 } : {}),
        });
      }
    }
  },
});

// Helper function to determine if a todo should be reset
function shouldResetTodo(frequency: "daily" | "weekly", lastReset: number, now: number): boolean {
  if (frequency === "daily") {
    const startOfToday = new Date(now);
    startOfToday.setHours(0, 0, 0, 0);
    return lastReset < startOfToday.getTime();
  }

  if (frequency === "weekly") {
    const date = new Date(now);
    const dayOfWeek = date.getDay();
    const startOfWeek = new Date(now);
    startOfWeek.setDate(date.getDate() - dayOfWeek);
    startOfWeek.setHours(0, 0, 0, 0);
    return lastReset < startOfWeek.getTime();
  }

  return false;
}
