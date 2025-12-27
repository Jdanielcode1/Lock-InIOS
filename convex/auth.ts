import { mutation, query, QueryCtx } from "./_generated/server";
import {
  customQuery,
  customCtx,
  customMutation,
} from "convex-helpers/server/customFunctions";

async function userCheck(ctx: QueryCtx) {
  const identity = await ctx.auth.getUserIdentity();
  if (identity === null) {
    throw new Error("Unauthenticated call");
  }
  return { identity };
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
