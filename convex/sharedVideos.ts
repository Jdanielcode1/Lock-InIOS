import { v } from "convex/values";
import { userMutation, userQuery } from "./auth";
import { action, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

// Mutation: Share a video with partners
export const shareVideo = userMutation({
  args: {
    r2Key: v.string(),
    thumbnailR2Key: v.optional(v.string()),
    durationMinutes: v.float64(),
    goalTitle: v.optional(v.string()),
    todoTitle: v.optional(v.string()),
    notes: v.optional(v.string()),
    // Accept as JSON string from iOS (ConvexMobile doesn't support arrays)
    partnerIdsJSON: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    // Parse partner IDs from JSON string
    const partnerIds: string[] = JSON.parse(args.partnerIdsJSON);

    // Verify all partner IDs are actually partners
    const partners = await ctx.db
      .query("accountabilityPartners")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();

    const activePartnerIds = partners
      .filter((p) => p.status === "active")
      .map((p) => p.partnerId);

    const validPartnerIds = partnerIds.filter((id) =>
      activePartnerIds.includes(id)
    );

    if (validPartnerIds.length === 0) {
      throw new Error("No valid partners to share with");
    }

    const videoId = await ctx.db.insert("sharedVideos", {
      userId,
      r2Key: args.r2Key,
      thumbnailR2Key: args.thumbnailR2Key,
      durationMinutes: args.durationMinutes,
      goalTitle: args.goalTitle,
      todoTitle: args.todoTitle,
      notes: args.notes,
      sharedWithPartnerIds: validPartnerIds,
      createdAt: Date.now(),
    });

    return videoId;
  },
});

// Query: List videos shared with the current user by partners
export const listSharedWithMe = userQuery({
  args: {},
  handler: async (ctx) => {
    const userId = ctx.identity.tokenIdentifier;

    // Get list of active partners
    const partners = await ctx.db
      .query("accountabilityPartners")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();

    const activePartnerIds = partners
      .filter((p) => p.status === "active")
      .map((p) => p.partnerId);

    if (activePartnerIds.length === 0) return [];

    // Get all videos from partners
    const allVideos = [];
    for (const partnerId of activePartnerIds) {
      const videos = await ctx.db
        .query("sharedVideos")
        .withIndex("by_user", (q) => q.eq("userId", partnerId))
        .collect();

      // Filter to videos shared with current user
      const sharedWithUser = videos.filter((v) =>
        v.sharedWithPartnerIds.includes(userId)
      );
      allVideos.push(...sharedWithUser);
    }

    // Sort by createdAt descending
    return allVideos.sort((a, b) => b.createdAt - a.createdAt);
  },
});

// Query: List videos the current user has shared
export const listMyShared = userQuery({
  args: {},
  handler: async (ctx) => {
    const userId = ctx.identity.tokenIdentifier;

    const videos = await ctx.db
      .query("sharedVideos")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .order("desc")
      .collect();

    return videos;
  },
});

// Action: Get a signed URL to view/download a shared video
export const getViewUrl = action({
  args: {
    videoId: v.id("sharedVideos"),
  },
  handler: async (ctx, args): Promise<string | null> => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }

    const userId = identity.tokenIdentifier;

    // Get the video record using internal query
    const video = await ctx.runQuery(internal.sharedVideos.getByIdInternal, {
      videoId: args.videoId,
    });

    if (!video) {
      throw new Error("Video not found");
    }

    // Check access - must be owner or in sharedWithPartnerIds
    if (
      video.userId !== userId &&
      !video.sharedWithPartnerIds.includes(userId)
    ) {
      throw new Error("Not authorized to view this video");
    }

    // Generate presigned URL using AWS SDK directly (bypasses r2.getUrl bug)
    const s3Client = new S3Client({
      region: "auto",
      endpoint: process.env.R2_ENDPOINT,
      credentials: {
        accessKeyId: process.env.R2_ACCESS_KEY_ID!,
        secretAccessKey: process.env.R2_SECRET_ACCESS_KEY!,
      },
    });

    const command = new GetObjectCommand({
      Bucket: process.env.R2_BUCKET,
      Key: video.r2Key,
    });

    const url = await getSignedUrl(s3Client, command, { expiresIn: 3600 });
    return url;
  },
});

// Action: Get thumbnail URL
export const getThumbnailUrl = action({
  args: {
    videoId: v.id("sharedVideos"),
  },
  handler: async (ctx, args): Promise<string | null> => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }

    const userId = identity.tokenIdentifier;

    // Get the video record using internal query
    const video = await ctx.runQuery(internal.sharedVideos.getByIdInternal, {
      videoId: args.videoId,
    });

    if (!video) {
      throw new Error("Video not found");
    }

    // Check access
    if (
      video.userId !== userId &&
      !video.sharedWithPartnerIds.includes(userId)
    ) {
      throw new Error("Not authorized to view this video");
    }

    if (!video.thumbnailR2Key) {
      return null;
    }

    // Generate presigned URL using AWS SDK directly (bypasses r2.getUrl bug)
    const s3Client = new S3Client({
      region: "auto",
      endpoint: process.env.R2_ENDPOINT,
      credentials: {
        accessKeyId: process.env.R2_ACCESS_KEY_ID!,
        secretAccessKey: process.env.R2_SECRET_ACCESS_KEY!,
      },
    });

    const command = new GetObjectCommand({
      Bucket: process.env.R2_BUCKET,
      Key: video.thumbnailR2Key,
    });

    const url = await getSignedUrl(s3Client, command, { expiresIn: 3600 });
    return url;
  },
});

// Internal query for actions to use (no auth required - called from authenticated actions)
export const getByIdInternal = internalQuery({
  args: { videoId: v.id("sharedVideos") },
  handler: async (ctx, args) => {
    return await ctx.db.get(args.videoId);
  },
});

// Public query for client use
export const getById = userQuery({
  args: { videoId: v.id("sharedVideos") },
  handler: async (ctx, args) => {
    return await ctx.db.get(args.videoId);
  },
});

// Mutation: Delete a shared video (owner only)
export const remove = userMutation({
  args: { videoId: v.id("sharedVideos") },
  handler: async (ctx, args) => {
    const userId = ctx.identity.tokenIdentifier;

    const video = await ctx.db.get(args.videoId);
    if (!video) throw new Error("Video not found");
    if (video.userId !== userId) throw new Error("Not authorized");

    // Delete from database (R2 deletion would need separate cleanup)
    await ctx.db.delete(args.videoId);

    return "deleted";
  },
});
