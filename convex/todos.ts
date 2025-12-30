import { v } from "convex/values";
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
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const todo = await ctx.db.get(args.id);
    if (!todo) throw new Error("Todo not found");
    if (todo.userId !== userId) throw new Error("Not authorized");

    await ctx.db.patch(args.id, {
      localVideoPath: args.localVideoPath,
      localThumbnailPath: args.localThumbnailPath,
      isCompleted: true,
    });
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
        isCompleted: true,
      });
    }
  },
});
