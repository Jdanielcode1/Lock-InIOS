// Firebase Authentication OIDC configuration
// Replace YOUR_FIREBASE_PROJECT_ID with your actual Firebase project ID
// You can find this in Firebase Console > Project Settings > General > Project ID
// Or in your GoogleService-Info.plist under PROJECT_ID
export default {
  providers: [
    {
      domain: `https://securetoken.google.com/${process.env.FIREBASE_PROJECT_ID}`,
      applicationID: process.env.FIREBASE_PROJECT_ID,
    },
  ],
};
