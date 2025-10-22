import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

// Query: List subtasks for a specific goal
export const listByGoal = query({
  args: { goalId: v.id("goals") },
  handler: async (ctx, args) => {
    const subtasks = await ctx.db
      .query("subtasks")
      .withIndex("by_goal", (q) => q.eq("goalId", args.goalId))
      .order("desc")
      .collect();
    return subtasks;
  },
});

// Mutation: Create a new subtask
export const create = mutation({
  args: {
    goalId: v.id("goals"),
    title: v.string(),
    description: v.string(),
    estimatedHours: v.float64(),
  },
  handler: async (ctx, args) => {
    const subtaskId = await ctx.db.insert("subtasks", {
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
export const updateProgress = mutation({
  args: {
    id: v.id("subtasks"),
    additionalHours: v.float64(),
  },
  handler: async (ctx, args) => {
    const subtask = await ctx.db.get(args.id);
    if (!subtask) throw new Error("Subtask not found");

    const newCompletedHours = subtask.completedHours + args.additionalHours;

    await ctx.db.patch(args.id, {
      completedHours: newCompletedHours,
    });

    return { completedHours: newCompletedHours };
  },
});

// Mutation: Delete a subtask
export const remove = mutation({
  args: { id: v.id("subtasks") },
  handler: async (ctx, args) => {
    await ctx.db.delete(args.id);
  },
});
