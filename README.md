# Bartender 101

A native iOS app for drilling drink recipes the way you'd need them behind a
bar: fast. It's an index-card deck of ~62 working-bar drinks — full spec on
every card (ingredients with amounts, glass, ice, method, garnish) — plus
three study modes on top of it:

- **Spaced Review** — cards you miss come back sooner, cards you nail come
  back later. The standard spaced-repetition trick for making a deck stick
  with the least total study time.
- **Speed Drill** — a name on screen, four ingredient lists, a clock. Trains
  actual recall speed, not just eventual recall.
- **Name That Drink** — the reverse direction: shown a spec, you name the
  drink. This is the direction you need when a guest describes what they
  want instead of asking for it by name.

Built as plain SwiftUI, iOS 17+, zero third-party dependencies. The drink
data lives in one file, [`Bartender101/Resources/drinks.json`](Bartender101/Resources/drinks.json),
so a future web version can reuse every recipe verbatim instead of
retyping the deck in a second language.

## Getting started

1. Clone the repo and open `Bartender101.xcodeproj` in Xcode 16 or later.
2. Press **⌘U** first. This runs the test suite, which is the fastest signal
   that everything — the deck, the scheduler math, the unit conversions —
   made it through intact.
3. Press **⌘R** to run in the iOS Simulator (iPhone 16 or similar).

No signing setup, no Swift Package dependencies to resolve — the project
should build immediately.

### Running on your own iPhone

1. In Xcode, select your iPhone as the run destination (connect it via
   cable, or over Wi-Fi once paired once).
2. Select the `Bartender101` project in the navigator → the `Bartender101`
   target → **Signing & Capabilities** → choose your Apple ID under **Team**.
   A free Apple ID works for this; you don't need a paid developer account
   to run your own app on your own device.
3. Change **Bundle Identifier** to something unique to you, e.g.
   `com.yourname.Bartender101` — the default `com.bartender101.Bartender101`
   will collide if anyone else has built this.
4. Press **⌘R**. The first time, your iPhone will ask you to trust the
   developer certificate: **Settings → General → VPN & Device Management**.

### If the project won't open

This project was built without ever being opened in Xcode — the environment
it was written in has no Mac available, only Linux. Everything down to the
`drinks.json` deck was checked as thoroughly as tooling allowed without a
compiler (schema validation, brace-balance checks, a full unit test suite),
but `Bartender101.xcodeproj/project.pbxproj` itself couldn't be opened to
confirm it loads. If Xcode reports it's damaged or won't open:

```
brew install xcodegen
xcodegen generate
```

This regenerates `Bartender101.xcodeproj` from [`project.yml`](project.yml)
and the files already on disk. Nothing about the app code needs to change —
this only rebuilds the project wrapper. Re-run it any time the project file
seems out of sync with what's on disk.

## Adding a drink

Every drink is one object in `Bartender101/Resources/drinks.json`. Copy an
existing entry as a template — here's a Negroni:

```json
{
  "id": "negroni",
  "name": "Negroni",
  "family": "manhattan",
  "glass": "rocks",
  "ice": "largeCube",
  "method": "stir",
  "difficulty": 1,
  "tags": ["classic"],
  "ingredients": [
    { "name": "Gin", "amountOz": 1, "unit": "oz" },
    { "name": "Campari", "amountOz": 1, "unit": "oz" },
    { "name": "Sweet vermouth", "amountOz": 1, "unit": "oz" }
  ],
  "garnish": "Orange peel, expressed",
  "notes": "Equal parts, stirred, served over one large cube. No citrus in the mix, so it's always stirred rather than shaken."
}
```

Valid values for each enum field:

| Field | Allowed values |
| --- | --- |
| `family` | `highball`, `mule`, `sour`, `oldFashioned`, `martini`, `manhattan`, `spritz`, `tiki`, `muddled`, `cream`, `shot`, `misc` |
| `glass` | `highball`, `collins`, `copperMug`, `rocks`, `coupe`, `martini`, `wine`, `flute`, `hurricane`, `julepCup`, `shot`, `irishCoffeeMug` |
| `ice` | `cubed`, `largeCube`, `crushed`, `none` |
| `method` | `build`, `shake`, `stir`, `muddle`, `blend`, `layer` |
| `tags` | `well`, `classic`, `shot`, `tiki`, `modern` |
| ingredient `unit` | `oz`, `topWith`, `dash`, `barspoon`, `rinse`, `splash`, `muddled`, `pinch`, `optional` |

An ingredient with a non-`oz` unit can optionally carry `dashCount`,
`approxCount`, or `spoonCount` for a nicer display label (e.g. `"dashCount":
3` renders as "3 dashes").

After editing, validate the file before opening Xcode:

```
node scripts/validate-drinks.js
```

This checks for duplicate ids/names, invalid enum values, missing amounts,
and that each drink's total pour is roughly sane for its family (catches,
e.g., a highball accidentally speced like a shot). It's the same check this
deck was validated with before being committed.

## Architecture

```
Bartender101.xcodeproj/   Xcode 16+ project (synchronized folder groups)
project.yml               XcodeGen fallback — see "If the project won't open"
scripts/validate-drinks.js

Bartender101/
  Bartender101App.swift   App entry point, tab layout
  Resources/drinks.json   The deck — shared with any future web build
  Models/                 Drink, Ingredient, Measure (oz/ml), ReviewState
  Data/                   DrinkLibrary (load/search), ReviewStore (persistence),
                           Scheduler (spaced-repetition math), FuzzyMatch
  Components/             DrinkCardView (the flip card), GradeButtons
  Features/
    Home/                 Study home, due count, drill entry points
    Browse/                Searchable/filterable deck, card detail view
    Review/                Spaced-repetition session
    SpeedDrill/            Timed multiple-choice drill
    Reverse/                Spec-to-name quiz
    Stats/                  Accuracy, weak drinks, per-family coverage
    Settings/               oz/ml toggle, drill timer, reset progress

Bartender101Tests/
  DrinkLibraryTests.swift   Deck decodes, no dupes, every drink well-formed
  SchedulerTests.swift      Spaced-repetition interval math
  MeasureTests.swift        oz→ml conversion, fraction formatting, fuzzy match
```

`Scheduler.swift` and `FuzzyMatch.swift` are written as pure functions with
no SwiftUI or storage dependency — the intent is that a future web version
can port this logic near-verbatim rather than redesigning it.

Progress is persisted as a single JSON file in Application Support (via
`ReviewStore`), not SwiftData — deliberately, so the persistence layer stays
something you can inspect and reason about directly, and so the same
`[String: ReviewState]` shape maps cleanly onto `localStorage` for a web
build later.

## Not built yet

Deliberately out of scope for this pass, but the architecture doesn't block
them:

- **Ticket Rush** — a game mode where orders arrive on a timer and you build
  drinks against the clock. The natural next step toward the web game you
  mentioned; `Scheduler` and the deck already support it.
- **Custom cards** — an in-app editor for house specials, rather than
  hand-editing `drinks.json`.
- **The web build itself** — `drinks.json` and `Scheduler.swift` are the two
  pieces designed to cross over directly.
