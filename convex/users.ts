import { v } from "convex/values";
import { userMutation, userQuery } from "./auth";
import { action, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";

// Helper: Generate a random 8-character alphanumeric invite code
function generateRandomCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // Excluded confusing chars: 0, O, I, 1
  let code = "";
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

// Query: Get the current user's invite code (generates one if not exists)
export const getMyInviteCode = userMutation({
  args: {},
  handler: async (ctx) => {
    const userId = ctx.identity.tokenIdentifier;

    // Find user record
    const user = await ctx.db
      .query("users")
      .withIndex("by_token", (q) => q.eq("tokenIdentifier", userId))
      .first();

    if (!user) {
      throw new Error("User not found");
    }

    // If user already has a code, return it
    if (user.inviteCode) {
      return user.inviteCode;
    }

    // Generate a unique invite code
    let code = generateRandomCode();
    let attempts = 0;
    const maxAttempts = 10;

    // Ensure uniqueness
    while (attempts < maxAttempts) {
      const existing = await ctx.db
        .query("users")
        .withIndex("by_invite_code", (q) => q.eq("inviteCode", code))
        .first();

      if (!existing) break;

      code = generateRandomCode();
      attempts++;
    }

    if (attempts >= maxAttempts) {
      throw new Error("Failed to generate unique invite code");
    }

    // Save the code
    await ctx.db.patch(user._id, { inviteCode: code });

    return code;
  },
});

// Internal query to look up user by invite code
export const _getUserByInviteCode = internalQuery({
  args: { code: v.string() },
  handler: async (ctx, args) => {
    const code = args.code.toUpperCase().trim();

    const user = await ctx.db
      .query("users")
      .withIndex("by_invite_code", (q) => q.eq("inviteCode", code))
      .first();

    if (!user) {
      return null;
    }

    // Return limited info (don't expose full user data)
    return {
      userId: user.tokenIdentifier,
      name: user.name,
      email: user.email,
    };
  },
});

// Action: Look up a user by their invite code (for deep linking - no auth required)
export const getUserByInviteCode = action({
  args: { code: v.string() },
  handler: async (ctx, args): Promise<{ userId: string; name?: string; email?: string } | null> => {
    return await ctx.runQuery(internal.users._getUserByInviteCode, { code: args.code });
  },
});

// Mutation: Register referral when a new user signs up with an invite code
export const registerReferral = userMutation({
  args: { inviteCode: v.string() },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const userEmail = ctx.identity.email;
    const userName = ctx.identity.name;
    const code = args.inviteCode.toUpperCase().trim();

    // Find current user's record
    const currentUser = await ctx.db
      .query("users")
      .withIndex("by_token", (q) => q.eq("tokenIdentifier", userId))
      .first();

    if (!currentUser) {
      throw new Error("User not found");
    }

    // Check if user already has a referrer
    if (currentUser.referredBy) {
      return { status: "already_referred" };
    }

    // Find the referrer by invite code
    const referrer = await ctx.db
      .query("users")
      .withIndex("by_invite_code", (q) => q.eq("inviteCode", code))
      .first();

    if (!referrer) {
      return { status: "invalid_code" };
    }

    // Can't refer yourself
    if (referrer.tokenIdentifier === userId) {
      return { status: "self_referral" };
    }

    // Check if already partners
    const existingPartner = await ctx.db
      .query("accountabilityPartners")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect()
      .then((partners) =>
        partners.find(
          (p) => p.partnerId === referrer.tokenIdentifier && p.status === "active"
        )
      );

    if (existingPartner) {
      return { status: "already_partners" };
    }

    const now = Date.now();

    // Update current user with referrer
    await ctx.db.patch(currentUser._id, { referredBy: referrer.tokenIdentifier });

    // Create bidirectional partner records (auto-accept referral partnership)
    // Record for the referrer
    await ctx.db.insert("accountabilityPartners", {
      userId: referrer.tokenIdentifier,
      partnerId: userId,
      partnerEmail: userEmail || "",
      partnerName: userName,
      status: "active",
      createdAt: now,
    });

    // Record for the new user
    await ctx.db.insert("accountabilityPartners", {
      userId: userId,
      partnerId: referrer.tokenIdentifier,
      partnerEmail: referrer.email || "",
      partnerName: referrer.name,
      status: "active",
      createdAt: now,
    });

    return {
      status: "success",
      referrerName: referrer.name,
    };
  },
});

// Mutation: Delete all user data (for account deletion)
// This deletes all goals, study sessions, todos, and goal todos for the current user
export const deleteAllData = userMutation({
  args: {},
  handler: async (ctx) => {
    const userId = ctx.identity.tokenIdentifier;

    // 1. Delete all study sessions
    const sessions = await ctx.db
      .query("studySessions")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();

    for (const session of sessions) {
      await ctx.db.delete(session._id);
    }

    // 2. Delete all goal todos
    const goalTodos = await ctx.db
      .query("goalTodos")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();

    for (const todo of goalTodos) {
      await ctx.db.delete(todo._id);
    }

    // 3. Delete all goals
    const goals = await ctx.db
      .query("goals")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();

    for (const goal of goals) {
      await ctx.db.delete(goal._id);
    }

    // 4. Delete all standalone todos
    const todos = await ctx.db
      .query("todos")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();

    for (const todo of todos) {
      await ctx.db.delete(todo._id);
    }

    return "All user data deleted successfully";
  },
});
