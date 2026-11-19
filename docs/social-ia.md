# The social layer's information architecture

A review of how a player meets the social layer (identity, sign-in, boards, profiles, certificates, screenshots) across the site and every game, and the structure it should have. Written November 2026, right after the layer shipped (#103). The first section is how it was; "What this change did" and "Left for Rob" are the outcome.

## The map, as shipped

| Where | What a player sees |
| --- | --- |
| **Play page** (every game) | A pill in the top-right corner: camera (screenshot, F9), trophy (this game's top 10 in a dialog), and a person icon with "Sign in" (before a player exists) or their silly name. It fades to 28% after 3.5 s idle. |
| **First clear** | Two toasts at once: "Cleared X: lesson. 1 of 5 rooms. [Share a screenshot]" and "You're on the leaderboard as Sleepy Prince 649, #1 in Git. [Change name] [See the board]". |
| **Name chip dialog** | Titled "You" (or "Keep your progress"): XP, rename, a Google button, and buttons "Your profile" (public `/u/<id>`), "Settings" (`/me/`), "Back to the game". |
| **Finishing a game** | "You earned a certificate!" dialog: the image, the name on it, "View and share it", "Keep playing". |
| **Site bar** (home, `/leaderboards/`, `/me/`, privacy) | Brand, the five games, Play. No leaderboards, no "you". |
| **Site bar** (Worker pages `/u/`, `/c/`, `/s/`) | Brand, "Leaderboards", "Your profile", Play. A different bar from the rest of the site. |
| **Game pages** (`/curb/`, `/prince/` …) | Their own themed bars; footers link Leaderboards. No social script loads. |
| **Home** | "Top of the class": top five overall, "Every leaderboard", "Your profile". |
| **`/leaderboards/`** | Tabs (Overall + five games), the latest certificates, "Your profile" at the very bottom. |
| **`/me/`** (private) | Kicker "Your profile". Name, stats and "Your public profile"; then Name, Your games, Certificates, Screenshots, Other devices (Google, save key), Leave (sign out, delete). |
| **`/u/<id>`** (public) | Name, stats, share row, per-game cards, certificates. The owner sees "Edit your profile" (to `/me/`). |
| **`/c/<id>`**, **`/s/<id>`** | The certificate (LinkedIn, download, print, owner rename) and the screenshot (owner delete), each linking the player's `/u/`. |
| **Avatar** | None anywhere. Google's picture is deliberately not kept. |

## Problems, worst first

1. **A guest doesn't learn that their progress hangs on one browser until it's too late.** The token lives in localStorage. Clear site data, switch browser or lose the phone, and the player, their place on the boards and the right to edit their certificates are stranded on the server. The only remedies (Google, the save key) sit in the fifth section of `/me/`, under "Other devices", which reads as "for people with two computers", not "for anyone who wants to keep this". Nothing prompts it at the moment it matters most, when a certificate is earned.
2. **"Your profile" means two pages.** The bar and the home and leaderboards links called "Your profile" pointed at the public `/u/<id>` once a player existed (and at `/me/` before), while `/me/` itself was headed "Your profile", the footer's "Your profile" went to `/me/`, and the play dialog had "Your profile" (public) beside "Settings" (`/me/`). On `/u/<own id>` the bar's "Your profile" linked to the page you were on. A player can't build a picture of "the page that's mine" from that.
3. **"Sign in" on the play page says a sign-up is needed.** Before the first clear the chip read "Sign in", the one word that contradicts the design (no sign-up). Clicking it opened a dialog explaining there's nothing to sign in to.
4. **No "you" in the site's chrome, and two different bars.** The static pages had no leaderboards or "you" in the bar; the Worker pages had both, but lost the games. Moving between `/leaderboards/` and a profile changed the whole navigation.
5. **No face.** Boards, profiles and the play chip are names only, so a player can't spot themselves at a glance, and the person icon is the same for everyone.
6. **Two toasts at the first clear.** The level toast and the welcome toast arrived together, over the bottom of the game, both with buttons. On a phone they cover a third of the screen.
7. **`/me/`'s order.** Renaming (rare) came first; the thing that protects the progress came fifth; "Sign out" sat under a section called "Leave" next to "Delete everything".
8. **The play dialog didn't say whether you're signed in.** A Google player saw "Your progress is saved to the cloud", the same as a guest.
9. **The leaderboards page put "Your profile" at the very bottom**, under the certificate feed, and the bar didn't mark the page as current.

What works and should stay: no sign-up at all; the player made on the first clear, with a name you can change; the trophy dialog for one game's board without leaving the game; certificates and screenshots as their own shareable pages with owner-only controls; the toolbar fading while you play; the privacy stance (only Google's `sub`).

## The structure

Three places, three names, used the same way everywhere:

- **Your progress** (`/me/`): private. Everything about you, and the settings. Every "me" link goes here.
- **Public profile** (`/u/<id>`): what others see. Linked from Your progress, from every board row, certificate and screenshot.
- **Leaderboards** (`/leaderboards/`): in the site bar on every site page.

And one face: a **pixel avatar** drawn from the player's id (a mirrored 5×5 sprite in one of eight colours, `site/static/social/avatar.js`). It needs no upload, stores nothing, and is the same in the browser and in the Worker's pages. It's the "profile picture" on the bar, the play toolbar, the boards, Your progress and the public profile.

## What this change did

- **Avatar** (`avatar.js`), shown on the play chip, every board row (in-game dialog, `/leaderboards/`, home), `/me/`'s header, `/u/`'s header, "Shared by" on screenshots and the player link on certificates.
- **You in the site bar**: once a player exists, `site.js` puts an avatar-and-name chip before Play, linking to `/me/` (avatar only on phones). Nothing for visitors without a player, so the marketing pages stay clean.
- **One bar**: the site's bar (`HOME_NAV`) and the Worker pages' bar are now the same: the five games and Leaderboards, plus the chip. `/leaderboards/` marks itself current.
- **Names**: `/me/` is "Your progress" (title, kicker, footer, home and play links); the public page is "public profile". `data-dq-me`'s switching to `/u/` is gone. The play dialog's buttons are "Your progress" and "Public profile". The owner's line on `/u/` reads "This is you, as everyone else sees you. [Your progress and settings]".
- **Play chip**: "Guest" (title "Playing as a guest: nothing to sign up for") before the first clear, the avatar and name after. Its dialog is titled with the player's name, shows the avatar, and says whether they're signed in with Google. A guest's Google line says why: "This browser is the only place that knows it's you."
- **First clear**: one toast, not two: "Cleared “The Hall of Seals”! You're on the leaderboard as Sleepy Prince 649, #1 in Prince of Versions. No sign-up needed. [Change name] [See the board]". (If the upload fails, the plain level toast still shows.)
- **Certificate dialog**: a guest gets a Google button under it: "Its link works for good. Sign in with Google to keep your progress, and the right to edit this certificate, if this browser's data is ever cleared."
- **`/me/` order**: header (avatar, name, stats), "Only you see this page. Others see your public profile"; for a guest, a highlighted **Keep your progress** card (Google, save key) comes next; then Your games, Certificates, Screenshots, Your name; for a Google player, **Your devices** (with Sign out) comes here instead; last **Delete your player**.
- The play page's cached player now refreshes after every upload, so the chip's XP is current.

## For engagement: the return loop

Rob then asked for whatever would help engagement most. Most visits land on the home page or a game's own page (the trailers link there), and neither knew a returning player. So:

- **Welcome back** (`site/static/social/resume.js`): on the home page and on every game's page, a returning player sees their avatar, "Welcome back, Sleepy Prince 649.", where they are ("1 of 5 rooms of Prince of Versions cleared. Next up: The Vizier's Seal (git reset).") and one button to carry on, in the page's own button style. The home page picks the game they played last (`/api/me` now says when each save was last played); a finished game points at its certificate and the next game. Their overall rank shows only when it's encouraging (top ten, or the top half). Newcomers see nothing.
- **Your row on every board**: when you're below the top ten (in a game) or the top five or fifty (the home page and `/leaderboards/`), your row appears under a gap, avatar and all, instead of a line of text.
- **The next game, straight after a certificate**: the certificate dialog adds "Next: learn SQL in Just One More JOIN", the next game in the site's order that isn't finished.

## Left for Rob

These are bigger or a matter of taste:

1. **The avatar on the images.** The certificate and profile PNGs (`cards.ts`) don't draw it yet. It's a 5×5 grid, so `png.ts` could draw it easily, but it changes the certificate design (bump `CERT_DESIGN`). Worth doing if the avatar sticks.
2. **Choosing your avatar.** Today it's fixed by the id. A "shuffle" (store a seed on the player) would be one column and a button, but it's a schema change on both databases.
3. **A nudge before a guest loses anything**, e.g. a one-time toast after the third clear: "Your progress lives in this browser. Keep it?" with the Google button. It would help problem 1 most, but every toast is an interruption in the game, so it's a judgement call.
4. **The game pages' own bars** (`/curb/`, `/prince/` …) still have no Leaderboards or "you". They don't load the social script and each bar is themed; adding the chip means loading `site.js` there.
5. **The play toolbar on phones** sits over the game's top-right corner. In landscape on a small phone it can cover game UI. Worth checking each game in its real export; if it clashes, move it to the top-left for that game, or collapse it into a single avatar button that opens a small menu.
6. **Sign out for a guest.** There's none on purpose (it would strand the player), but a shared computer has no way to leave without deleting. A "Forget me on this browser (copy your save key first)" button would cover it.
7. ~~A board row for "you" when you're not in the top 10/50.~~ Done, see above.
