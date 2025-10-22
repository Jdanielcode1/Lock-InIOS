import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  goals: defineTable({
    title: v.string(),
    description: v.string(),
    targetHours: v.float64(),
    completedHours: v.float64(),
    status: v.union(v.literal("active"), v.literal("completed"), v.literal("paused")),
    createdAt: v.float64(),
  }).index("by_status", ["status"]),

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
    videoStorageId: v.string(),
    thumbnailStorageId: v.optional(v.string()),
    durationMinutes: v.float64(),
    uploadedAt: v.float64(),
  })
    .index("by_goal", ["goalId"])
    .index("by_subtask", ["subtaskId"]),
});
