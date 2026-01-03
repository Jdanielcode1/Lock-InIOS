import { R2 } from "@convex-dev/r2";
import { components } from "./_generated/api";

// Initialize R2 client with the component
export const r2 = new R2(components.r2);

// Expose client API for upload URL generation
export const { generateUploadUrl, syncMetadata } = r2.clientApi({
  // Validate upload permissions - ensure user is authenticated
  checkUpload: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Must be authenticated to upload files");
    }
    // Could add file size limits, type validation, etc.
  },
  // Handle post-upload logic
  onUpload: async (ctx, _bucket, key) => {
    // Log the upload for debugging
    console.log(`File uploaded with key: ${key}`);
  },
});
