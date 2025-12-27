import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  goals: defineTable({
    title: v.string(),
    description: v.string(),
    targetHours: v.float64(),
    completedHours: v.float64(),
    status: v.union(v.literal("active"), v.literal("completed"), v.literal("paused")),
    isArchived: v.optional(v.boolean()),
    createdAt: v.float64(),
  })
    .index("by_status", ["status"])
    .index("by_archived", ["isArchived"]),

  subtasks: defineTable({
    goalId: v.id("goals"),
    title: v.string(),
    description: v.string(),
    estimatedHours: v.float64(),
    completedHours: v.float64(),
    createdAt: v.float64(),
  }).index("by_goal", ["goalId"]),

  studySessions: defineTable({
    goalId: v.id("goals"),
    subtaskId: v.optional(v.id("subtasks")),
    localVideoPath: v.string(),
    localThumbnailPath: v.optional(v.string()),
    durationMinutes: v.float64(),
    createdAt: v.float64(),
  })
    .index("by_goal", ["goalId"])
    .index("by_subtask", ["subtaskId"]),

  todos: defineTable({
    title: v.string(),
    description: v.optional(v.string()),
    isCompleted: v.boolean(),
    isArchived: v.optional(v.boolean()),
    localVideoPath: v.optional(v.string()),
    localThumbnailPath: v.optional(v.string()),
    createdAt: v.float64(),
  })
    .index("by_completed", ["isCompleted"])
    .index("by_archived", ["isArchived"]),
});
