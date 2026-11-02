// Settings for the daily leaderboard, player accounts and visitor numbers.
// Fill these in after setting up Supabase (see "Set up Supabase" in README.md).
// While they're empty, the game works on its own and the leaderboard and accounts stay hidden.
// The publishable key is meant to be public. Never put a secret key here.
window.GUESSTIMATE_BOARD = {
  url: "https://axndmvxmqrrsukehqvhs.supabase.co", // your Project URL, like "https://abcdefghijklmnop.supabase.co"
  key: "sb_publishable_nd87hYRSi-b_SmPVq28tTQ_XtrbZIxk",  // your publishable key, like "sb_publishable_..."
  // Optional: Cloudflare Web Analytics token (see "Visitor numbers" in README.md). Leave empty to turn it off.
  analytics: "f559139d882c4010ae16a3e9b6363e43",
  // Optional: Google OAuth client ID. With it, "Continue with Google" goes straight to Google and back
  // to this site, so Google's screen shows playguesstimate.com. Public by design, not a secret.
  google: "533577647719-4cmhbm8hr1329j44fdonet6q7t5me75a.apps.googleusercontent.com"
};
