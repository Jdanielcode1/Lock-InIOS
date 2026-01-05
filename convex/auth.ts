import { mutation, query, QueryCtx } from "./_generated/server";
import {
  customQuery,
  customCtx,
  customMutation,
} from "convex-helpers/server/customFunctions";

// Standard Convex auth pattern:
// Both queries and mutations throw when unauthenticated
// Client handles auth state before making calls

async function userCheck(ctx: QueryCtx) {
  const identity = await ctx.auth.getUserIdentity();
  if (identity === null) {
    throw new Error("Unauthenticated call");
  }
  return { identity };
}

// Helper to get identity or null (for queries that need graceful handling)
export async function getUserIdentityOrNull(ctx: QueryCtx) {
  return await ctx.auth.getUserIdentity();
}

// Use `userQuery` instead of `query` to require authentication
export const userQuery = customQuery(
  query,
  customCtx(async (ctx) => {
    return await userCheck(ctx);
  })
);

// Use `userMutation` instead of `mutation` to require authentication
export const userMutation = customMutation(
  mutation,
  customCtx(async (ctx) => {
    return await userCheck(ctx);
  })
);
