import { v } from "convex/values";
import { paginationOptsValidator } from "convex/server";
import { action, query } from "./_generated/server";
import { userMutation, userQuery } from "./auth";

// Query: List all non-archived goals for the current user
export const list = userQuery({
  args: {},
  handler: async (ctx) => {
    const userId = ctx.identity.tokenIdentifier;
    const goals = await ctx.db
      .query("goals")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .order("desc")
      .collect();
    return goals.filter((goal) => !goal.isArchived);
  },
});

// Query: List archived goals for the current user
export const listArchived = userQuery({
  args: {},
  handler: async (ctx) => {
    const userId = ctx.identity.tokenIdentifier;
    const goals = await ctx.db
      .query("goals")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .order("desc")
      .collect();
    return goals.filter((goal) => goal.isArchived === true);
  },
});

// Query: List archived goals with pagination
export const listArchivedPaginated = userQuery({
  args: { paginationOpts: paginationOptsValidator },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    const results = await ctx.db
      .query("goals")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .order("desc")
      .paginate(args.paginationOpts);

    // Filter to only archived items
    return {
      ...results,
      page: results.page.filter((goal) => goal.isArchived === true),
    };
  },
});

// Query: Get a specific goal by ID (with ownership check)
// Uses regular query to allow graceful handling when unauthenticated
export const get = query({
  args: { id: v.id("goals") },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      return null;
    }
    const userId = identity.tokenIdentifier;
    const goal = await ctx.db.get(args.id);
    if (goal && goal.userId !== userId) {
      return null; // Not authorized, return null instead of throwing
    }
    return goal;
  },
});

// Mutation: Create a new goal
export const create = userMutation({
  args: {
    title: v.string(),
    description: v.string(),
    targetHours: v.float64(),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const goalId = await ctx.db.insert("goals", {
      userId,
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
export const updateProgress = userMutation({
  args: {
    id: v.id("goals"),
    additionalHours: v.float64(),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const goal = await ctx.db.get(args.id);
    if (!goal) throw new Error("Goal not found");
    if (goal.userId !== userId) throw new Error("Not authorized");

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
export const updateStatus = userMutation({
  args: {
    id: v.id("goals"),
    status: v.union(v.literal("active"), v.literal("completed"), v.literal("paused")),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const goal = await ctx.db.get(args.id);
    if (!goal) throw new Error("Goal not found");
    if (goal.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, {
      status: args.status,
    });
  },
});

// Mutation: Update goal title
export const updateTitle = userMutation({
  args: {
    id: v.id("goals"),
    title: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const goal = await ctx.db.get(args.id);
    if (!goal) throw new Error("Goal not found");
    if (goal.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, {
      title: args.title,
    });
  },
});

// Mutation: Archive a goal
export const archive = userMutation({
  args: { id: v.id("goals") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const goal = await ctx.db.get(args.id);
    if (!goal) throw new Error("Goal not found");
    if (goal.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, {
      isArchived: true,
    });
  },
});

// Mutation: Unarchive a goal
export const unarchive = userMutation({
  args: { id: v.id("goals") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const goal = await ctx.db.get(args.id);
    if (!goal) throw new Error("Goal not found");
    if (goal.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, {
      isArchived: false,
    });
  },
});

// Mutation: Delete a goal
export const remove = userMutation({
  args: { id: v.id("goals") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const goal = await ctx.db.get(args.id);
    if (!goal) throw new Error("Goal not found");
    if (goal.userId !== userId) throw new Error("Not authorized");

    await ctx.db.delete(args.id);
  },
});

// Action wrapper for iOS - fetch archived goals
export const fetchArchivedPaginated = action({
  args: {
    numItems: v.number(),
    cursor: v.optional(v.string()),
  },
  handler: async (ctx, args): Promise<{
    page: Array<{
      _id: string;
      title: string;
      description: string;
      targetHours: number;
      completedHours: number;
      status: string;
      isArchived?: boolean;
      createdAt: number;
    }>;
    continueCursor: string | null;
    isDone: boolean;
  }> => {
    const result = await ctx.runQuery(
      // @ts-ignore - internal API
      "goals:listArchivedPaginated" as any,
      { paginationOpts: { numItems: args.numItems, cursor: args.cursor ?? null } }
    );
    return {
      page: result.page.map((g: any) => ({
        _id: g._id,
        title: g.title,
        description: g.description,
        targetHours: g.targetHours,
        completedHours: g.completedHours,
        status: g.status,
        isArchived: g.isArchived,
        createdAt: g.createdAt,
      })),
      continueCursor: result.continueCursor,
      isDone: result.isDone,
    };
  },
});
