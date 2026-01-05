import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  // Users table for storing user profiles
  users: defineTable({
    tokenIdentifier: v.string(), // User ID
    email: v.optional(v.string()),
    name: v.optional(v.string()),
    pictureUrl: v.optional(v.string()),
    createdAt: v.float64(),
    // Invite system
    inviteCode: v.optional(v.string()), // Unique 8-char code for sharing
    referredBy: v.optional(v.string()), // tokenIdentifier of user who referred this user
  })
    .index("by_token", ["tokenIdentifier"])
    .index("by_invite_code", ["inviteCode"]),

  goals: defineTable({
    userId: v.string(), // User ID
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
    userId: v.string(), // User ID
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
    userId: v.string(), // User ID
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
    userId: v.string(), // User ID
    title: v.string(),
    description: v.optional(v.string()),
    isCompleted: v.boolean(),
    isArchived: v.optional(v.boolean()),
    localVideoPath: v.optional(v.string()),
    localThumbnailPath: v.optional(v.string()),
    videoNotes: v.optional(v.string()), // Notes/description for the attached video
    speedSegmentsJSON: v.optional(v.string()), // JSON array of speed segments for accurate stopwatch in recaps
    createdAt: v.float64(),
  })
    .index("by_user", ["userId"])
    .index("by_user_completed", ["userId", "isCompleted"])
    .index("by_user_archived", ["userId", "isArchived"]),

  // Accountability Partners - bidirectional partnership records
  accountabilityPartners: defineTable({
    userId: v.string(), // The user who has this partner
    partnerId: v.string(), // The partner's userId (tokenIdentifier)
    partnerEmail: v.string(), // For display purposes
    partnerName: v.optional(v.string()),
    status: v.union(
      v.literal("pending"), // Invite sent, waiting
      v.literal("active"), // Both accepted
      v.literal("declined") // Partner declined
    ),
    createdAt: v.float64(),
  })
    .index("by_user", ["userId"])
    .index("by_partner", ["partnerId"])
    .index("by_user_status", ["userId", "status"]),

  // Partner Invites - for inviting users by email (may not exist yet)
  partnerInvites: defineTable({
    fromUserId: v.string(),
    fromUserEmail: v.string(),
    fromUserName: v.optional(v.string()),
    toEmail: v.string(), // Email to invite (may not exist as user yet)
    toUserId: v.optional(v.string()), // Filled when user signs up/matches
    status: v.union(
      v.literal("pending"),
      v.literal("accepted"),
      v.literal("declined"),
      v.literal("expired")
    ),
    createdAt: v.float64(),
    expiresAt: v.float64(), // 7 days from creation
  })
    .index("by_from_user", ["fromUserId"])
    .index("by_to_email", ["toEmail"])
    .index("by_to_user", ["toUserId"]),

  // Shared Videos - videos uploaded to R2 and shared with partners
  sharedVideos: defineTable({
    userId: v.string(), // Who shared
    r2Key: v.string(), // R2 storage key
    thumbnailR2Key: v.optional(v.string()),
    durationMinutes: v.float64(),
    goalTitle: v.optional(v.string()),
    todoTitle: v.optional(v.string()),
    notes: v.optional(v.string()),
    sharedWithPartnerIds: v.array(v.string()), // Partner userIds who can view
    createdAt: v.float64(),
  })
    .index("by_user", ["userId"])
    .index("by_created", ["createdAt"]),
});
