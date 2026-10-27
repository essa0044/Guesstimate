# Guesstimate

**How good is your eye?** Guesstimate is a daily estimation game you play in the browser. Five quick rounds, about two minutes, and the same set for everyone each day so scores are easy to compare and share.

## The games

| Game | What you do |
| --- | --- |
| **Pour** | Guess how full a glass is *by volume*. Flasks, wine glasses and vases make height a bad guide. |
| **Flash** | Three frames of dots flash by. Guess the total across all three. |
| **Angle** | Name the angle in degrees by eye. |
| **Center** | Tap the exact center of a circle or arc, or the midpoint of a line. |
| **Hold** | Hold a button for exactly the target time, with no clock to watch. |
| **Shade** | Memorize a color, then pick which of two shades is closer. Five picks, each harder. |
| **Glimpse** | Keep your eyes on the center while a star flashes for a split second somewhere else. Tap where it was. |
| **Bounce** | Watch a ball fly, then predict where it lands after it bounces out of sight in the fog. |
| **Ballpark** | Estimate a product, a sum or a percentage before 7 seconds run out. |

Glimpse, Bounce and Ballpark are inspired by Lumosity's Eagle Eye, Pinball Recall and Raindrops, but like every Guesstimate game they score how close you get, not just right or wrong.

Every round scores 0 to 100, so a full day tops out at 500.

## Today's five

Pour and Flash appear every day. The other three slots rotate among Angle, Center, Hold, Shade, Glimpse, Bounce and Ballpark. Each day's rounds come from a seed based on the date, so everyone gets the same puzzles. After playing you can copy an emoji result to share:

```
Guesstimate No. 1 · 412/500
🟩🟨🟩🟩🟥
Pour 92 · Flash 71 · Angle 88 · Center 95 · Hold 66
```

The day follows each player's own clock. Puzzle No. 13 is everyone's 27 October, so a player in New York gets it hours after a player in Shanghai, and each new set starts at local midnight.

There's also a practice mode for each game (five rounds that get harder), plus a streak, games played and personal bests. These are saved in the player's own browser.

## Daily leaderboard

After the daily five, players can post their score under a name and see their rank against everyone who played the same puzzle, wherever they live. The leaderboard runs on a free [Supabase](https://supabase.com) database. Until it's connected, the game works as before and the leaderboard stays hidden.

Set it up (about 10 minutes):

1. Create a free Supabase account and a new project. Pick the region closest to most of your players, for example Frankfurt.
2. In the project, open **SQL Editor**, click **New query**, paste everything from [`supabase/leaderboard.sql`](supabase/leaderboard.sql) and click **Run**.
3. Open the project's **Connect** dialog, or **Settings → API Keys**, and copy the **Project URL** and the **publishable key** (it starts with `sb_publishable_`). Never use a secret key here.
4. Edit [`board-config.js`](board-config.js) in this repository, paste both values and commit. The leaderboard appears on the results screen of the daily five.

How it works:

- Players choose a name the first time they post. Their first score of the day is the one that counts.
- Scores are only accepted for a date that is "today" somewhere on Earth, so each day's board stays open until midnight in the last time zone.
- Browsers can't read or change the scores table directly. They go through two database functions that check every score.
- To remove a name, delete its row in **Table Editor → daily_scores**.

Limits: Supabase's free plan includes a 500 MB database and pauses a project after a week without activity, which a daily game won't hit. Scores are checked for shape (five rounds of 0 to 100 points) but come from the player's browser, so a determined cheater could post a fake one. Re-scoring each guess on the server is the fix if that becomes a problem.

## Run it locally

It's a single file with no build step. Open `index.html` in a browser, or serve the folder:

```sh
python3 -m http.server 8000
# then visit http://localhost:8000
```

## Put it online with GitHub Pages

1. In this repository, go to **Settings → Pages**.
2. Under **Build and deployment**, set **Source** to *Deploy from a branch*, pick `main` and `/ (root)`, and save.
3. After a minute the game is live at `https://essa0044.github.io/Guesstimate/`.

## Project layout

```
index.html               the whole game: markup, styles and script
board-config.js          leaderboard address and publishable key (empty until set up)
supabase/leaderboard.sql database setup for the daily leaderboard
favicon.svg              browser tab and home-screen icon
manifest.webmanifest     lets phones add the game to the home screen
```

## Roadmap

- **App version:** the game is already built phone-first, so it can be wrapped as a native app for the App Store and Google Play with a tool such as [Capacitor](https://capacitorjs.com/).
- **Cheat-proof leaderboard:** re-score each player's guesses on the server so fake scores can't be posted.
- **Instagram:** reveal posts ("this glass looks half full, it's actually 19%") and color challenges where followers comment their pick before the answer.

## License

All rights reserved for now. Add a license file if you want others to be able to reuse the code.
