import { v } from "convex/values";
import { userMutation, userQuery } from "./auth";

// Query: List subtasks for a specific goal
export const listByGoal = userQuery({
  args: { goalId: v.id("goals") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    // Verify goal ownership
    const goal = await ctx.db.get(args.goalId);
    if (!goal) throw new Error("Goal not found");
    if (goal.userId !== userId) throw new Error("Not authorized");

    const subtasks = await ctx.db
      .query("subtasks")
      .withIndex("by_goal", (q) => q.eq("goalId", args.goalId))
      .order("desc")
      .collect();
    return subtasks;
  },
});

// Mutation: Create a new subtask
export const create = userMutation({
  args: {
    goalId: v.id("goals"),
    title: v.string(),
    description: v.string(),
    estimatedHours: v.float64(),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    // Verify goal ownership
    const goal = await ctx.db.get(args.goalId);
    if (!goal) throw new Error("Goal not found");
    if (goal.userId !== userId) throw new Error("Not authorized");

    const subtaskId = await ctx.db.insert("subtasks", {
      userId,
      goalId: args.goalId,
      title: args.title,
      description: args.description,
      estimatedHours: args.estimatedHours,
      completedHours: 0,
      createdAt: Date.now(),
    });
    return subtaskId;
  },
});

// Mutation: Update subtask progress
export const updateProgress = userMutation({
  args: {
    id: v.id("subtasks"),
    additionalHours: v.float64(),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const subtask = await ctx.db.get(args.id);
    if (!subtask) throw new Error("Subtask not found");
    if (subtask.userId !== userId) throw new Error("Not authorized");

    const newCompletedHours = subtask.completedHours + args.additionalHours;

    await ctx.db.patch(args.id, {
      completedHours: newCompletedHours,
    });

    return { completedHours: newCompletedHours };
  },
});

// Mutation: Delete a subtask
export const remove = userMutation({
  args: { id: v.id("subtasks") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const subtask = await ctx.db.get(args.id);
    if (!subtask) throw new Error("Subtask not found");
    if (subtask.userId !== userId) throw new Error("Not authorized");

    await ctx.db.delete(args.id);
  },
});
