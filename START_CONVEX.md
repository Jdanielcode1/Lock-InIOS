# Starting Convex Development Server

Since you already have a deployment URL configured (`https://grateful-poodle-804.convex.cloud`), you need to connect this project to that deployment.

## Steps:

1. **Open a new Terminal window** and navigate to your project:
   ```bash
   cd /Users/dcantu/Desktop/IOS_DEV/Lock-In-repo/LockIn
   ```

2. **Start Convex dev server**:
   ```bash
   npx convex dev
   ```

3. **When prompted**, select:
   - "Configure an existing project"
   - Choose your `grateful-poodle-804` deployment
   - Wait for functions to deploy

4. **Verify it's running**:
   You should see output like:
   ```
   ✓ Convex functions ready!
   👀 Watching for file changes...
   ```

## What This Does:

- Creates a `.convex/` directory with your deployment config
- Deploys all your functions (goals.ts, subtasks.ts, studySessions.ts, schema.ts)
- Watches for file changes and hot-reloads
- Enables the iOS app to connect to your backend

## Keep It Running:

Leave this terminal window open while developing. The server needs to be running for:
- Real-time data sync in your iOS app
- File uploads
- All mutations and queries

## Test Connection:

Once it's running, you can verify with:
```bash
npx convex run goals:list
```

This should return an empty array `[]` if no goals exist yet.

---

After this is running, your iOS app will be able to connect and sync data in real-time! 🚀
