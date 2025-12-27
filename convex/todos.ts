import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

// Query: List all non-archived todos
export const list = query({
  args: {},
  handler: async (ctx) => {
    const todos = await ctx.db.query("todos").order("desc").collect();
    return todos.filter((todo) => !todo.isArchived);
  },
});

// Query: List archived todos
export const listArchived = query({
  args: {},
  handler: async (ctx) => {
    const todos = await ctx.db.query("todos").order("desc").collect();
    return todos.filter((todo) => todo.isArchived === true);
  },
});

// Query: Get a specific todo by ID
export const get = query({
  args: { id: v.id("todos") },
  handler: async (ctx, args) => {
    const todo = await ctx.db.get(args.id);
    return todo;
  },
});

// Mutation: Create a new todo
export const create = mutation({
  args: {
    title: v.string(),
    description: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const todoId = await ctx.db.insert("todos", {
      title: args.title,
      description: args.description,
      isCompleted: false,
      createdAt: Date.now(),
    });
    return todoId;
  },
});

// Mutation: Toggle todo completion status
export const toggle = mutation({
  args: {
    id: v.id("todos"),
    isCompleted: v.boolean(),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.id, {
      isCompleted: args.isCompleted,
    });
  },
});

// Mutation: Attach video to todo (and mark as completed)
export const attachVideo = mutation({
  args: {
    id: v.id("todos"),
    localVideoPath: v.string(),
    localThumbnailPath: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.id, {
      localVideoPath: args.localVideoPath,
      localThumbnailPath: args.localThumbnailPath,
      isCompleted: true,
    });
  },
});

// Mutation: Archive a todo
export const archive = mutation({
  args: { id: v.id("todos") },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.id, {
      isArchived: true,
    });
  },
});

// Mutation: Unarchive a todo
export const unarchive = mutation({
  args: { id: v.id("todos") },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.id, {
      isArchived: false,
    });
  },
});

// Mutation: Delete a todo
export const remove = mutation({
  args: { id: v.id("todos") },
  handler: async (ctx, args) => {
    await ctx.db.delete(args.id);
  },
});
