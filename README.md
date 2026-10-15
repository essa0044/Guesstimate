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

Every round scores 0 to 100, so a full day tops out at 500.

## Today's five

Pour and Flash appear every day. The other three slots rotate among Angle, Center, Hold and Shade. Each day's rounds come from a seed based on the date, so everyone gets the same puzzles. After playing you can copy an emoji result to share:

```
Guesstimate No. 1 · 412/500
🟩🟨🟩🟩🟥
Pour 92 · Flash 71 · Angle 88 · Center 95 · Hold 66
```

There's also a practice mode for each game (five rounds that get harder), plus a streak, games played and personal bests. These are saved in the player's own browser.

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
index.html            the whole game: markup, styles and script
favicon.svg           browser tab and home-screen icon
manifest.webmanifest  lets phones add the game to the home screen
```

## Roadmap

- **App version:** the game is already built phone-first, so it can be wrapped as a native app for the App Store and Google Play with a tool such as [Capacitor](https://capacitorjs.com/).
- **Global leaderboard:** needs a small backend to store daily scores.
- **Instagram:** reveal posts ("this glass looks half full, it's actually 19%") and color challenges where followers comment their pick before the answer.

## License

All rights reserved for now. Add a license file if you want others to be able to reuse the code.
