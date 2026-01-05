import { mutation, query, QueryCtx } from "./_generated/server";
import {
  customQuery,
  customCtx,
  customMutation,
} from "convex-helpers/server/customFunctions";

// Convex Philosophy: Keep It Simple
// - Queries return empty/null when unauthenticated (graceful)
// - Mutations throw when unauthenticated (security)
// - Subscriptions auto-update when auth becomes valid

// For queries - return identity or null (don't throw)
// Queries will return empty results when identity is null
async function userCheckForQuery(ctx: QueryCtx) {
  const identity = await ctx.auth.getUserIdentity();
  return { identity }; // Can be null - queries handle this gracefully
}

// For mutations - throw if not authenticated (security requirement)
async function userCheckForMutation(ctx: QueryCtx) {
  const identity = await ctx.auth.getUserIdentity();
  if (identity === null) {
    throw new Error("Unauthenticated call");
  }
  return { identity };
}

// Helper to get identity or null
export async function getUserIdentityOrNull(ctx: QueryCtx) {
  return await ctx.auth.getUserIdentity();
}

// Use `userQuery` instead of `query` - returns empty when unauthenticated
export const userQuery = customQuery(
  query,
  customCtx(async (ctx) => {
    return await userCheckForQuery(ctx);
  })
);

// Use `userMutation` instead of `mutation` - throws when unauthenticated
export const userMutation = customMutation(
  mutation,
  customCtx(async (ctx) => {
    return await userCheckForMutation(ctx);
  })
);
