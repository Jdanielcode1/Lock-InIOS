import { v } from "convex/values";
import { userMutation, userQuery } from "./auth";

const INVITE_EXPIRY_DAYS = 7;

// Query: List all active partners for the current user
export const list = userQuery({
  args: {},
  handler: async (ctx) => {
    const userId = ctx.identity.tokenIdentifier;
    const partners = await ctx.db
      .query("accountabilityPartners")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    return partners.filter((p) => p.status === "active");
  },
});

// Query: List pending invites sent by the current user
export const listSentInvites = userQuery({
  args: {},
  handler: async (ctx) => {
    const userId = ctx.identity.tokenIdentifier;
    const invites = await ctx.db
      .query("partnerInvites")
      .withIndex("by_from_user", (q) => q.eq("fromUserId", userId))
      .collect();
    return invites.filter((i) => i.status === "pending");
  },
});

// Query: List invites received by the current user (by email match)
export const listReceivedInvites = userQuery({
  args: {},
  handler: async (ctx) => {
    const userId = ctx.identity.tokenIdentifier;
    const userEmail = ctx.identity.email;

    if (!userEmail) return [];

    // Find invites sent to this user's email
    const invites = await ctx.db
      .query("partnerInvites")
      .withIndex("by_to_email", (q) => q.eq("toEmail", userEmail.toLowerCase()))
      .collect();

    // Filter for pending invites not sent by self
    return invites.filter(
      (i) => i.status === "pending" && i.fromUserId !== userId
    );
  },
});

// Mutation: Send a partner invite by email
export const sendInvite = userMutation({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const userEmail = ctx.identity.email;
    const userName = ctx.identity.name;
    const targetEmail = args.email.toLowerCase().trim();

    if (!userEmail) {
      throw new Error("Your account doesn't have an email");
    }

    // Can't invite yourself
    if (targetEmail === userEmail.toLowerCase()) {
      throw new Error("You can't invite yourself");
    }

    // Check if already invited this email
    const existingInvite = await ctx.db
      .query("partnerInvites")
      .withIndex("by_from_user", (q) => q.eq("fromUserId", userId))
      .collect()
      .then((invites) =>
        invites.find(
          (i) => i.toEmail === targetEmail && i.status === "pending"
        )
      );

    if (existingInvite) {
      throw new Error("You already have a pending invite to this email");
    }

    // Check if already partners
    const existingPartner = await ctx.db
      .query("accountabilityPartners")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect()
      .then((partners) =>
        partners.find(
          (p) => p.partnerEmail === targetEmail && p.status === "active"
        )
      );

    if (existingPartner) {
      throw new Error("You're already partners with this user");
    }

    // Check if the target email is already a user
    const targetUser = await ctx.db
      .query("users")
      .withIndex("by_token", (q) => q.eq("tokenIdentifier", targetEmail))
      .first();

    const now = Date.now();
    const expiresAt = now + INVITE_EXPIRY_DAYS * 24 * 60 * 60 * 1000;

    // Create the invite
    const inviteId = await ctx.db.insert("partnerInvites", {
      fromUserId: userId,
      fromUserEmail: userEmail,
      fromUserName: userName,
      toEmail: targetEmail,
      toUserId: targetUser?.tokenIdentifier,
      status: "pending",
      createdAt: now,
      expiresAt,
    });

    return inviteId;
  },
});

// Mutation: Accept a received invite
export const acceptInvite = userMutation({
  args: { inviteId: v.id("partnerInvites") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;
    const userEmail = ctx.identity.email;
    const userName = ctx.identity.name;

    const invite = await ctx.db.get(args.inviteId);
    if (!invite) throw new Error("Invite not found");

    // Verify invite is for this user
    if (userEmail?.toLowerCase() !== invite.toEmail.toLowerCase()) {
      throw new Error("This invite is not for you");
    }

    if (invite.status !== "pending") {
      // Return gracefully if already processed
      if (invite.status === "accepted") {
        return "already_accepted";
      }
      throw new Error("This invite was " + invite.status);
    }

    // Check if expired
    if (Date.now() > invite.expiresAt) {
      await ctx.db.patch(args.inviteId, { status: "expired" });
      throw new Error("Invite has expired");
    }

    // Update invite status
    await ctx.db.patch(args.inviteId, {
      status: "accepted",
      toUserId: userId,
    });

    const now = Date.now();

    // Create bidirectional partner records
    // Record for the person who sent the invite
    await ctx.db.insert("accountabilityPartners", {
      userId: invite.fromUserId,
      partnerId: userId,
      partnerEmail: userEmail!,
      partnerName: userName,
      status: "active",
      createdAt: now,
    });

    // Record for the person accepting
    await ctx.db.insert("accountabilityPartners", {
      userId: userId,
      partnerId: invite.fromUserId,
      partnerEmail: invite.fromUserEmail,
      partnerName: invite.fromUserName,
      status: "active",
      createdAt: now,
    });

    return "accepted";
  },
});

// Mutation: Decline a received invite
export const declineInvite = userMutation({
  args: { inviteId: v.id("partnerInvites") },
  handler: async (ctx, args) => {
    const userEmail = ctx.identity.email;

    const invite = await ctx.db.get(args.inviteId);
    if (!invite) throw new Error("Invite not found");

    // Verify invite is for this user
    if (userEmail?.toLowerCase() !== invite.toEmail.toLowerCase()) {
      throw new Error("This invite is not for you");
    }

    if (invite.status !== "pending") {
      // Return gracefully if already processed
      if (invite.status === "declined") {
        return "already_declined";
      }
      throw new Error("This invite was " + invite.status);
    }

    await ctx.db.patch(args.inviteId, { status: "declined" });

    return "declined";
  },
});

// Mutation: Cancel a sent invite
export const cancelInvite = userMutation({
  args: { inviteId: v.id("partnerInvites") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    const invite = await ctx.db.get(args.inviteId);
    if (!invite) throw new Error("Invite not found");

    // Verify invite was sent by this user
    if (invite.fromUserId !== userId) {
      throw new Error("This is not your invite");
    }

    if (invite.status !== "pending") {
      throw new Error("Can only cancel pending invites");
    }

    await ctx.db.delete(args.inviteId);

    return "cancelled";
  },
});

// Mutation: Remove an active partner
export const removePartner = userMutation({
  args: { partnerId: v.id("accountabilityPartners") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    const partnerRecord = await ctx.db.get(args.partnerId);
    if (!partnerRecord) throw new Error("Partner record not found");

    // Verify this is the user's partner record
    if (partnerRecord.userId !== userId) {
      throw new Error("Not authorized");
    }

    // Delete this user's record
    await ctx.db.delete(args.partnerId);

    // Also delete the partner's corresponding record
    const reverseRecord = await ctx.db
      .query("accountabilityPartners")
      .withIndex("by_user", (q) => q.eq("userId", partnerRecord.partnerId))
      .collect()
      .then((records) =>
        records.find((r) => r.partnerId === userId && r.status === "active")
      );

    if (reverseRecord) {
      await ctx.db.delete(reverseRecord._id);
    }

    return "removed";
  },
});

// Query: Get shared videos from a specific partner
export const getPartnerActivity = userQuery({
  args: { partnerId: v.string() },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    // Verify they are actually partners
    const partnerRecord = await ctx.db
      .query("accountabilityPartners")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect()
      .then((records) =>
        records.find(
          (r) => r.partnerId === args.partnerId && r.status === "active"
        )
      );

    if (!partnerRecord) {
      throw new Error("Not partners with this user");
    }

    // Get videos shared by this partner that include the current user
    const sharedVideos = await ctx.db
      .query("sharedVideos")
      .withIndex("by_user", (q) => q.eq("userId", args.partnerId))
      .order("desc")
      .collect();

    // Filter to only videos shared with the current user
    return sharedVideos.filter((v) =>
      v.sharedWithPartnerIds.includes(userId)
    );
  },
});

// Query: Get count of pending received invites (for badge)
export const getPendingInviteCount = userQuery({
  args: {},
  handler: async (ctx) => {
    const userEmail = ctx.identity.email;

    if (!userEmail) return 0;

    const invites = await ctx.db
      .query("partnerInvites")
      .withIndex("by_to_email", (q) => q.eq("toEmail", userEmail.toLowerCase()))
      .collect();

    return invites.filter((i) => i.status === "pending").length;
  },
});
