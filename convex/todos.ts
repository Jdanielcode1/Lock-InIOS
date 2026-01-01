import { v } from "convex/values";
import { paginationOptsValidator } from "convex/server";
import { action } from "./_generated/server";
import { userMutation, userQuery } from "./auth";

// Query: List all non-archived todos for the current user
export const list = userQuery({
  args: {},
  handler: async (ctx) => {
    const userId = ctx.identity.tokenIdentifier;
    const todos = await ctx.db
      .query("todos")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .order("desc")
      .collect();
    return todos.filter((todo) => !todo.isArchived);
  },
});

// Query: List archived todos for the current user
export const listArchived = userQuery({
  args: {},
  handler: async (ctx) => {
    const userId = ctx.identity.tokenIdentifier;
    const todos = await ctx.db
      .query("todos")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .order("desc")
      .collect();
    return todos.filter((todo) => todo.isArchived === true);
  },
});

// Query: List archived todos with pagination
export const listArchivedPaginated = userQuery({
  args: { paginationOpts: paginationOptsValidator },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    const results = await ctx.db
      .query("todos")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .order("desc")
      .paginate(args.paginationOpts);

    // Filter to only archived items
    return {
      ...results,
      page: results.page.filter((todo) => todo.isArchived === true),
    };
  },
});

// Query: List completed todos with pagination (for timeline)
export const listCompletedPaginated = userQuery({
  args: { paginationOpts: paginationOptsValidator },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    const results = await ctx.db
      .query("todos")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .order("desc")
      .paginate(args.paginationOpts);

    // Filter to only completed non-archived items
    return {
      ...results,
      page: results.page.filter((todo) => todo.isCompleted && !todo.isArchived),
    };
  },
});

// Query: Get a specific todo by ID (with ownership check)
export const get = userQuery({
  args: { id: v.id("todos") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (todo && todo.userId !== userId) {
      throw new Error("Not authorized");
    }
    return todo;
  },
});

// Mutation: Create a new todo
export const create = userMutation({
  args: {
    title: v.string(),
    description: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todoId = await ctx.db.insert("todos", {
      userId,
      title: args.title,
      description: args.description,
      isCompleted: false,
      createdAt: Date.now(),
    });
    return todoId;
  },
});

// Mutation: Toggle todo completion status
export const toggle = userMutation({
  args: {
    id: v.id("todos"),
    isCompleted: v.boolean(),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (!todo) throw new Error("Todo not found");
    if (todo.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, {
      isCompleted: args.isCompleted,
    });
  },
});

// Mutation: Update todo title and description
export const update = userMutation({
  args: {
    id: v.id("todos"),
    title: v.string(),
    description: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (!todo) throw new Error("Todo not found");
    if (todo.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, {
      title: args.title,
      description: args.description,
    });
  },
});

// Mutation: Attach video to todo (and mark as completed)
export const attachVideo = userMutation({
  args: {
    id: v.id("todos"),
    localVideoPath: v.string(),
    localThumbnailPath: v.optional(v.string()),
    videoNotes: v.optional(v.string()),
    speedSegmentsJSON: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (!todo) throw new Error("Todo not found");
    if (todo.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, {
      localVideoPath: args.localVideoPath,
      localThumbnailPath: args.localThumbnailPath,
      videoNotes: args.videoNotes,
      speedSegmentsJSON: args.speedSegmentsJSON,
      isCompleted: true,
    });
  },
});

// Mutation: Update video notes for a todo
export const updateVideoNotes = userMutation({
  args: {
    id: v.id("todos"),
    videoNotes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (!todo) throw new Error("Todo not found");
    if (todo.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, { videoNotes: args.videoNotes });
  },
});

// Mutation: Archive a todo
export const archive = userMutation({
  args: { id: v.id("todos") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (!todo) throw new Error("Todo not found");
    if (todo.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, {
      isArchived: true,
    });
  },
});

// Mutation: Unarchive a todo
export const unarchive = userMutation({
  args: { id: v.id("todos") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (!todo) throw new Error("Todo not found");
    if (todo.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, {
      isArchived: false,
    });
  },
});

// Mutation: Delete a todo
export const remove = userMutation({
  args: { id: v.id("todos") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (!todo) throw new Error("Todo not found");
    if (todo.userId !== userId) throw new Error("Not authorized");

    await ctx.db.delete(args.id);
  },
});

// Mutation: Attach same video to multiple todos (for session recordings)
export const attachVideoToMultiple = userMutation({
  args: {
    ids: v.array(v.id("todos")),
    localVideoPath: v.string(),
    localThumbnailPath: v.optional(v.string()),
    speedSegmentsJSON: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    // Verify ownership and attach video to each todo
    for (const id of args.ids) {
      const todo = await ctx.db.get(id);
      if (!todo) continue; // Skip if todo doesn't exist
      if (todo.userId !== userId) continue; // Skip if not authorized

      await ctx.db.patch(id, {
        localVideoPath: args.localVideoPath,
        localThumbnailPath: args.localThumbnailPath,
        speedSegmentsJSON: args.speedSegmentsJSON,
        isCompleted: true,
      });
    }
  },
});

// Action wrapper for iOS - fetch archived todos
export const fetchArchivedPaginated = action({
  args: {
    numItems: v.number(),
    cursor: v.optional(v.string()),
  },
  handler: async (ctx, args): Promise<{
    page: Array<{
      _id: string;
      title: string;
      description?: string;
      isCompleted: boolean;
      isArchived?: boolean;
      localVideoPath?: string;
      localThumbnailPath?: string;
      videoNotes?: string;
      speedSegmentsJSON?: string;
      createdAt: number;
    }>;
    continueCursor: string | null;
    isDone: boolean;
  }> => {
    const result = await ctx.runQuery(
      // @ts-ignore - internal API
      "todos:listArchivedPaginated" as any,
      { paginationOpts: { numItems: args.numItems, cursor: args.cursor ?? null } }
    );
    return {
      page: result.page.map((t: any) => ({
        _id: t._id,
        title: t.title,
        description: t.description,
        isCompleted: t.isCompleted,
        isArchived: t.isArchived,
        localVideoPath: t.localVideoPath,
        localThumbnailPath: t.localThumbnailPath,
        videoNotes: t.videoNotes,
        speedSegmentsJSON: t.speedSegmentsJSON,
        createdAt: t.createdAt,
      })),
      continueCursor: result.continueCursor,
      isDone: result.isDone,
    };
  },
});

// Action wrapper for iOS - fetch completed todos
export const fetchCompletedPaginated = action({
  args: {
    numItems: v.number(),
    cursor: v.optional(v.string()),
  },
  handler: async (ctx, args): Promise<{
    page: Array<{
      _id: string;
      title: string;
      description?: string;
      isCompleted: boolean;
      localVideoPath?: string;
      localThumbnailPath?: string;
      videoNotes?: string;
      speedSegmentsJSON?: string;
      createdAt: number;
    }>;
    continueCursor: string | null;
    isDone: boolean;
  }> => {
    const result = await ctx.runQuery(
      // @ts-ignore - internal API
      "todos:listCompletedPaginated" as any,
      { paginationOpts: { numItems: args.numItems, cursor: args.cursor ?? null } }
    );
    return {
      page: result.page.map((t: any) => ({
        _id: t._id,
        title: t.title,
        description: t.description,
        isCompleted: t.isCompleted,
        localVideoPath: t.localVideoPath,
        localThumbnailPath: t.localThumbnailPath,
        videoNotes: t.videoNotes,
        speedSegmentsJSON: t.speedSegmentsJSON,
        createdAt: t.createdAt,
      })),
      continueCursor: result.continueCursor,
      isDone: result.isDone,
    };
  },
});
