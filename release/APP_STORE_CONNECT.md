# House Pour — App Store Connect & TestFlight

Everything to paste into App Store Connect for the first TestFlight build,
plus the click-by-click steps. Pages are served from `/docs` via GitHub Pages.

## URLs (live once GitHub Pages is on)

| What | URL |
| --- | --- |
| Marketing | https://sidebyrner.github.io/bartender-101/ |
| Privacy Policy | https://sidebyrner.github.io/bartender-101/privacy.html |
| Support | https://sidebyrner.github.io/bartender-101/support.html |

## App record (New App)

| Field | Value |
| --- | --- |
| Platform | iOS |
| Name | House Pour: Bartender's Book (fallback: House Pour: Bar Specs) |
| Primary language | English (U.S.) |
| Bundle ID | com.connorbyrne.housepour |
| SKU | housepour-ios-001 |
| User access | Full access |

## App Information

| Field | Value |
| --- | --- |
| Subtitle (30 max) | Specs, drills & house drinks |
| Category | Food & Drink (secondary: Education) |
| Content rights | Does not contain, show, or access third-party content |
| Age rating | Answer "Frequent/Intense" for **Alcohol, Tobacco, or Drug Use or References**; "None" for everything else. Result: 18+ |

## App Privacy

- Data collection: **No, we do not collect data from this app.**
- Result shown on the store: **Data Not Collected**.
- Privacy Policy URL: see the table above.

## TestFlight → Test Information

**Beta App Description**

> House Pour is a pocket spec book for bartenders. Look up around 180 drinks fast and scale them to a shot, double, or batch; drill specs with spaced review, a speed drill, and a name-that-drink quiz; and develop your own house drinks from a classic ratio, through testing with tasting notes and photos, all the way onto your menu. Everything stays on your device. For adults of legal drinking age.

**What to Test**

> Thanks for testing House Pour! Please focus on:
> 1. Lookup speed mid-shift — Search, one-tap scaling (Shot / 2× / Batch), Bar Mode, and Made it logging. Is anything slow or hard to hit with wet hands?
> 2. Study drills — Spaced Review, Speed Drill, and Name That Drink. Do they feel fair and useful?
> 3. Building house drinks — New Drink, the ingredient picker, the balance meter, the board and list, tasting notes, and photos.
> 4. Bugs and anything confusing — especially the intro and your first few minutes.
> Spot a spec that looks wrong? Screenshot it and send it with TestFlight feedback.

| Field | Value |
| --- | --- |
| Feedback Email | hello@connorbyrne.net |
| Marketing URL | Marketing URL above |
| Privacy Policy URL | Privacy URL above |
| Beta App Review contact | Connor Byrne · hello@connorbyrne.net · (your phone) |
| Sign-in required | No |

**Review Notes** (Beta App Review and App Review)

> No account or sign-in. All content is bundled; nothing is sent to a server. The camera is only used when the user taps Take Photo on a drink page to keep a personal photo record, and library photos come through the system PhotosPicker. The app is a reference and training tool for bartenders and is intended for adults of legal drinking age (noted on the first intro screen). To see the drink builder: Build tab → New Drink → From a classic ratio → Sour.

## App Store listing (for later, when submitting for review)

**Promotional text (170)**

> The spec book behind the bar: find any drink fast, drill it until it sticks, and take your own ideas from first sketch to the menu.

**Keywords (100)**

> bartender,cocktail,recipes,bar,mixology,drink specs,flashcards,study,bartending,menu,spirits

**Description**

> House Pour is the spec book for people who work behind the bar.
>
> LOOK IT UP
> • Search around 180 drinks by name or ingredient
> • Scale any recipe to a shot, a double, or a batch in one tap, with dilution worked out for batches
> • Bartending Mode: big text and big buttons you can read at arm's length
> • Log what you make with Made it and see tonight's shift at a glance
>
> LEARN IT COLD
> • Spaced Review brings back the drinks you miss
> • Speed Drill puts a clock on recalling ingredients
> • Name That Drink trains the direction guests actually order in
>
> INVENT YOUR OWN
> • Start a house drink from a classic ratio, a riff on any drink, or a blank canvas
> • A live balance meter flags pours that run too sweet, too sour, or too big
> • Move ideas from Idea to Testing to On the Menu on a board or list
> • Keep tasting notes, star ratings, and photos for every version
>
> No accounts, no ads, no tracking. Everything stays on your device.
>
> For adults of legal drinking age. Please drink responsibly.

---

## Steps

1. **Merge the PR** for `drink-builder` into `main`, then `git checkout main && git pull`.
2. **GitHub Pages:** repo **Settings → Pages → Build and deployment → Deploy from a branch → `main` / `/docs` → Save**. Wait a minute, then open the three URLs above.
3. **App Store Connect → Apps → + → New App**, and fill in the "App record" table. If the name is taken, use the fallback.
4. Fill in **App Information**, **App Privacy**, and the **age rating**.
5. **Archive in Xcode:** open `Bartender101.xcodeproj` (run `xcodegen generate` first if needed). Set the destination to **Any iOS Device (arm64)** → **Product → Archive**. Signing is automatic with team H9B7A5KQP3; Xcode creates the distribution certificate and profile on first archive.
6. **Organizer → Distribute App → TestFlight & App Store → Distribute.** Processing takes about 5–30 minutes; watch for the email.
7. **TestFlight tab:** fill in **Test Information** (above).
8. **External Testing → + → New Group** (e.g. "Bartenders"). Add the build, submit for **Beta App Review** (usually under a day), then turn on a **Public Link** or invite testers by email.
9. **Every later build:** bump `CURRENT_PROJECT_VERSION` in `project.yml` (2, 3, …), run `xcodegen generate`, archive, and distribute.
