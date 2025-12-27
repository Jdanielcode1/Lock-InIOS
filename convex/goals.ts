import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

// Query: List all non-archived goals
export const list = query({
  args: {},
  handler: async (ctx) => {
    const goals = await ctx.db.query("goals").order("desc").collect();
    return goals.filter((goal) => !goal.isArchived);
  },
});

// Query: List archived goals
export const listArchived = query({
  args: {},
  handler: async (ctx) => {
    const goals = await ctx.db.query("goals").order("desc").collect();
    return goals.filter((goal) => goal.isArchived === true);
  },
});

// Query: Get a specific goal by ID
export const get = query({
  args: { id: v.id("goals") },
  handler: async (ctx, args) => {
    const goal = await ctx.db.get(args.id);
    return goal;
  },
});

// Mutation: Create a new goal
export const create = mutation({
  args: {
    title: v.string(),
    description: v.string(),
    targetHours: v.float64(),
  },
  handler: async (ctx, args) => {
    const goalId = await ctx.db.insert("goals", {
      title: args.title,
      description: args.description,
      targetHours: args.targetHours,
      completedHours: 0,
      status: "active",
      createdAt: Date.now(),
    });
    return goalId;
  },
});

// Mutation: Update goal progress
export const updateProgress = mutation({
  args: {
    id: v.id("goals"),
    additionalHours: v.float64(),
  },
  handler: async (ctx, args) => {
    const goal = await ctx.db.get(args.id);
    if (!goal) throw new Error("Goal not found");

    const newCompletedHours = goal.completedHours + args.additionalHours;
    const status = newCompletedHours >= goal.targetHours ? "completed" : "active";

    await ctx.db.patch(args.id, {
      completedHours: newCompletedHours,
      status,
    });

    return { completedHours: newCompletedHours, status };
  },
});

// Mutation: Update goal status
export const updateStatus = mutation({
  args: {
    id: v.id("goals"),
    status: v.union(v.literal("active"), v.literal("completed"), v.literal("paused")),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.id, {
      status: args.status,
    });
  },
});

// Mutation: Archive a goal
export const archive = mutation({
  args: { id: v.id("goals") },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.id, {
      isArchived: true,
    });
  },
});

// Mutation: Unarchive a goal
export const unarchive = mutation({
  args: { id: v.id("goals") },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.id, {
      isArchived: false,
    });
  },
});

// Mutation: Delete a goal
export const remove = mutation({
  args: { id: v.id("goals") },
  handler: async (ctx, args) => {
    await ctx.db.delete(args.id);
  },
});
