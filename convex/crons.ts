import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

// Run every hour to reset recurring goal todos
crons.hourly(
  "reset-recurring-goal-todos",
  { minuteUTC: 0 },
  internal.goalTodos.resetAllRecurringTodos
);

export default crons;
