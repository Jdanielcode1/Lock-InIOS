import { userMutation } from "./auth";

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
