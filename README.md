# Guesstimate

**How good is your eye?** Guesstimate is a daily estimation game you play in the browser. Five quick rounds, about two minutes, and the same set for everyone each day so scores are easy to compare and share.

## The games

| Game | What you do |
| --- | --- |
| **Pour** | Guess how full a glass is *by volume*. Flasks, wine glasses and vases make height a bad guide. |
| **Flash** | Three frames of dots flash by. Guess the total across all three. |
| **Angle** | Name the angle in degrees by eye. |
| **Center** | Tap the exact center of a circle or arc, or the midpoint of a line. |
| **Timer** | Tap to start a hidden stopwatch and tap again when you think the target time is up. Space bar works on a computer. |
| **Shade** | Memorize a color, then pick which of two shades is closer. Five picks, each harder. |
| **Glimpse** | Keep your eyes on the center while a star flashes for a split second somewhere else. Tap where it was. |
| **Bounce** | Watch a ball fly, then predict where it lands after it bounces out of sight in the fog. |
| **Ballpark** | Estimate a product, a sum or a percentage before 7 seconds run out. |

Glimpse, Bounce and Ballpark are inspired by Lumosity's Eagle Eye, Pinball Recall and Raindrops, but like every Guesstimate game they score how close you get, not just right or wrong.

Every round scores 0 to 100, so a full day tops out at 500.

## Today's five

Pour and Flash appear every day. The other three slots rotate among Angle, Center, Timer, Shade, Glimpse, Bounce and Ballpark. Each day's rounds come from a seed based on the date, so everyone gets the same puzzles. After playing you can copy an emoji result to share:

```
Guesstimate No. 1 · 412/500
🟩🟨🟩🟩🟥
Pour 92 · Flash 71 · Angle 88 · Center 95 · Timer 66
```

The day follows each player's own clock. Puzzle No. 13 is everyone's 27 October, so a player in New York gets it hours after a player in Shanghai, and each new set starts at local midnight.

There's also a practice mode for each game (five rounds that get harder), plus a streak, games played and personal bests.

## Accounts or guest play

On their first visit, players choose: **create an account** or **play as a guest**.

- **Guests** play straight away. Their streak and bests are saved in their own browser, and they type a name when they post to the leaderboard.
- **Accounts** sign up with a name, email and password (or Google, if you turn it on). Their name is reserved on the leaderboard, and their streak, games played, best day and today's result follow them to every device.
- A guest who later makes an account, or signs in, keeps the scores they posted as a guest on that device, so the streak carries over.
- Players can delete their account themselves from the account screen. That removes the login, the name and every score.

## Daily leaderboard

After the daily five, players see their rank against everyone who played the same puzzle, wherever they live. Accounts post automatically under their name; guests pick a name. The leaderboard and accounts run on a free [Supabase](https://supabase.com) project. Until it's connected, the game works on its own and both stay hidden.

### Set up Supabase (about 10 minutes)

1. Create a free Supabase account and a new project. Pick the region closest to most of your players, for example Frankfurt.
2. In the project, open **SQL Editor**, click **New query**, paste everything from [`supabase/setup.sql`](supabase/setup.sql) and click **Run**. It's safe to run again, and it upgrades a project that ran the older leaderboard-only script. Run it again whenever this file changes.
3. Open the project's **Connect** dialog, or **Settings → API Keys**, and copy the **Project URL** and the **publishable key** (it starts with `sb_publishable_`). Never use a secret key here.
4. Edit [`board-config.js`](board-config.js), paste both values and commit.
5. Open **Authentication → URL Configuration**. Set **Site URL** to the game's address (`https://playguesstimate.com/`) and add the same address under **Redirect URLs**. Confirmation and password-reset emails link there.
6. Open **Authentication → Sign In / Providers → Email** and choose how sign-up works:
   - **Confirm email off:** players are signed in right after creating an account. Simplest to start with.
   - **Confirm email on:** players must click a link in an email first. Supabase's built-in email sends only a few emails an hour, so connect your own email service under **Authentication → Emails → SMTP Settings** before you launch. [Resend](https://resend.com) and similar services have free plans.
7. Optional: to offer **Continue with Google**, enable Google under **Sign In / Providers** and follow Supabase's steps to create a Google OAuth client. The button appears in the game by itself once Google is on. Add a Google sign-in section to `privacy.html` when you do.

### How it works

- Each player's first score of the day is the one that counts.
- Scores are only accepted for a date that is "today" somewhere on Earth, so each day's board stays open until midnight in the last time zone.
- Browsers can't read or change the tables directly. They go through database functions that check every score and never send out emails or player ids.
- A guest can't post under a name that belongs to an account.
- To remove a name, delete its row in **Table Editor → daily_scores**. To rename an account, edit its row in **Table Editor → profiles**. To delete an account, use **Authentication → Users**; its profile goes with it.

Limits: Supabase's free plan includes a 500 MB database and 50,000 monthly active users, and pauses a project after a week without activity, which a daily game won't hit. Scores are checked for shape (five rounds of 0 to 100 points) but come from the player's browser, so a determined cheater could post a fake one. Re-scoring each guess on the server is the fix if that becomes a problem.

## Visitor numbers

Two places show how the game is doing:

- **Cloudflare Web Analytics** counts visits, where visitors come from and which devices they use, without cookies. Create a free Cloudflare account, open **Analytics & Logs → Web Analytics**, click **Add a site**, enter the game's address and copy the token from the snippet it shows (the value after `"token":`). Paste it into `analytics` in [`board-config.js`](board-config.js) and commit.
- **Supabase** knows how many people actually played. Paste the queries from [`supabase/stats.sql`](supabase/stats.sql) into the SQL Editor to see players per day, new versus returning players, how many come back the next day and within a week, and how many accounts there are.

## Legal pages (Germany)

[`impressum.html`](impressum.html) and [`privacy.html`](privacy.html) are templates for a site run from Germany. Replace every yellow-highlighted `<span class="todo">[...]</span>` with your own details before you promote the game:

- `impressum.html`: your full name, street address, postcode and city, email, and a phone number (or another way to reach you quickly).
- `privacy.html`: your full name, your email, and the region of your Supabase project (shown in the project's settings in Supabase).

Update `privacy.html` before adding ads, Google sign-in or any other outside service, and add a consent banner when ads go live. These pages are a starting point, not legal advice; a generator such as e-recht24 or a lawyer can check them.

The game's fonts and its Supabase library are served from this repository (`fonts/`, `vendor/`), so visitors' browsers don't contact Google Fonts or other outside servers.

## Adding a game

Each game is one entry in `MODES` in `index.html`, with its name in `ORDER` for the practice list. To put a new game into the daily rotation without changing today's or any earlier puzzle, give it a start date in `LATER`:

```js
const LATER = { newgame: "2026-12-01" };
```

From that date the daily five draws its three rotating slots from the larger pool. Days before it keep exactly the puzzles they had.

## Custom domain

The game lives at **https://playguesstimate.com**. The domain is registered at Porkbun: an ALIAS record for the root and a `www` CNAME both point to `essa0044.github.io`, and the domain is verified in GitHub's Pages settings so nobody else can claim it. If the address ever changes, replace `https://playguesstimate.com/` in `index.html` (three places, for link previews) and in Supabase's **Site URL** and **Redirect URLs**. Players' guest streaks are saved per address, so they don't carry over to a new domain; account streaks do.

## Run it locally

It's a single file with no build step. Open `index.html` in a browser, or serve the folder:

```sh
python3 -m http.server 8000
# then visit http://localhost:8000
```

## Put it online with GitHub Pages

1. In this repository, go to **Settings → Pages**.
2. Under **Build and deployment**, set **Source** to *Deploy from a branch*, pick `main` and `/ (root)`, and save.
3. After a minute the game is live. With the custom domain set (see above), that's `https://playguesstimate.com/`.

## Project layout

```
index.html               the whole game: markup, styles and script
board-config.js          Supabase address, publishable key and analytics token
about.html               how to play, scoring and FAQ
privacy.html             privacy policy (Datenschutzerklärung) template
impressum.html           legal notice template
pages.css                shared styles for the three pages above
supabase/setup.sql       database setup for the leaderboard and accounts
supabase/stats.sql       player numbers and retention queries
fonts/                   self-hosted fonts (SIL Open Font License)
vendor/supabase.js       Supabase client library (MIT License)
og-image.png             preview image for shared links
favicon.svg, icon-*.png  browser tab and home-screen icons
manifest.webmanifest     lets phones add the game to the home screen
```

## Roadmap

- **App version:** the game is already built phone-first, so it can be wrapped as a native app for the App Store and Google Play with a tool such as [Capacitor](https://capacitorjs.com/).
- **Cheat-proof leaderboard:** re-score each player's guesses on the server so fake scores can't be posted.
- **Instagram:** reveal posts ("this glass looks half full, it's actually 19%") and color challenges where followers comment their pick before the answer.

## License

All rights reserved for now. Add a license file if you want others to be able to reuse the code.
