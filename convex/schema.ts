import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  // Users table for storing user profiles
  users: defineTable({
    tokenIdentifier: v.string(), // Auth0 user ID
    email: v.optional(v.string()),
    name: v.optional(v.string()),
    pictureUrl: v.optional(v.string()),
    createdAt: v.float64(),
  }).index("by_token", ["tokenIdentifier"]),

  goals: defineTable({
    userId: v.string(), // Auth0 user ID
    title: v.string(),
    description: v.string(),
    targetHours: v.float64(),
    completedHours: v.float64(),
    status: v.union(v.literal("active"), v.literal("completed"), v.literal("paused")),
    isArchived: v.optional(v.boolean()),
    createdAt: v.float64(),
  })
    .index("by_user", ["userId"])
    .index("by_user_status", ["userId", "status"])
    .index("by_user_archived", ["userId", "isArchived"]),

  // Goal Todos - tasks within goals (replacing subtasks)
  goalTodos: defineTable({
    userId: v.string(), // Auth0 user ID
    goalId: v.id("goals"),
    title: v.string(),
    description: v.optional(v.string()),
    // Todo type: "simple" = checkbox only, "hours" = tracks hours
    todoType: v.union(v.literal("simple"), v.literal("hours")),
    // For hours-based todos only
    estimatedHours: v.optional(v.float64()),
    completedHours: v.optional(v.float64()),
    // Completion status
    isCompleted: v.boolean(),
    isArchived: v.optional(v.boolean()),
    // Recurring configuration
    frequency: v.union(v.literal("none"), v.literal("daily"), v.literal("weekly")),
    lastResetAt: v.optional(v.float64()), // Timestamp of last auto-reset
    // Video attachment
    localVideoPath: v.optional(v.string()),
    localThumbnailPath: v.optional(v.string()),
    videoDurationMinutes: v.optional(v.float64()),
    videoNotes: v.optional(v.string()), // Notes/description for the attached video
    createdAt: v.float64(),
  })
    .index("by_goal", ["goalId"])
    .index("by_user", ["userId"]),

  studySessions: defineTable({
    userId: v.string(), // Auth0 user ID
    goalId: v.id("goals"),
    goalTodoId: v.optional(v.id("goalTodos")),
    localVideoPath: v.string(),
    localThumbnailPath: v.optional(v.string()),
    durationMinutes: v.float64(),
    notes: v.optional(v.string()), // Notes/description for the session
    createdAt: v.float64(),
  })
    .index("by_goal", ["goalId"])
    .index("by_goal_todo", ["goalTodoId"])
    .index("by_user", ["userId"]),

  todos: defineTable({
    userId: v.string(), // Auth0 user ID
    title: v.string(),
    description: v.optional(v.string()),
    isCompleted: v.boolean(),
    isArchived: v.optional(v.boolean()),
    localVideoPath: v.optional(v.string()),
    localThumbnailPath: v.optional(v.string()),
    createdAt: v.float64(),
  })
    .index("by_user", ["userId"])
    .index("by_user_completed", ["userId", "isCompleted"])
    .index("by_user_archived", ["userId", "isArchived"]),
});
