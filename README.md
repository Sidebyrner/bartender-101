# Bartender 101

Two native iOS apps sharing one drink database, for the two halves of
learning to bartend: memorizing recipes before a shift, and looking one up
fast — scaled to whatever size it needs to be — during one.

- **Bartender101** — an index-card deck of ~62 working-bar drinks with three
  study modes (Spaced Review, Speed Drill, Name That Drink) for drilling
  recipes into muscle memory. See [below](#bartender101-the-study-app) for
  details.
- **Drinks Codex** — a ~180-drink searchable encyclopedia built around
  resizing a recipe on the spot: a servings multiplier, shot/single/double
  presets, a batch/pitcher mode that accounts for the dilution a big batch
  won't get from being shaken or stirred to order, and an oz⇄ml toggle. See
  [below](#drinks-codex-the-reference-app) for details.

Both apps read the same [`Shared/Resources/drinks.json`](Shared/Resources/drinks.json)
and compile the same model/data layer in [`Shared/`](Shared) — a recipe
fixed once is correct in both apps, and a future web build has one file and
one set of pure functions to port rather than two.

Built as plain SwiftUI, iOS 17+, zero third-party dependencies.

## Getting started

1. Clone the repo. **Run `xcodegen generate` before opening the project the
   first time** — see [If the project won't open](#if-the-project-wont-open)
   for why this is the recommended first step rather than a fallback here.
2. Open `Bartender101.xcodeproj` in Xcode 16 or later.
3. Pick a scheme in the toolbar: **Bartender101** or **DrinksCodex**. Each
   builds and runs independently.
4. Press **⌘U** on either scheme first — the test suite is the fastest
   signal that the shared deck, models, and math made it through intact.
5. Press **⌘R** to run in the iOS Simulator (iPhone 16 or similar).

No signing setup, no Swift Package dependencies to resolve.

### Running on your own iPhone

1. In Xcode, select your iPhone as the run destination (connect it via
   cable, or over Wi-Fi once paired once).
2. Select the project in the navigator → the target you're running
   (`Bartender101` or `DrinksCodex`) → **Signing & Capabilities** → choose
   your Apple ID under **Team**. A free Apple ID works; no paid developer
   account needed to run your own app on your own device.
3. Change **Bundle Identifier** to something unique to you, e.g.
   `com.yourname.Bartender101` — the defaults
   (`com.bartender101.Bartender101`, `com.bartender101.DrinksCodex`) will
   collide if anyone else has built this.
4. Press **⌘R**. The first time, your iPhone will ask you to trust the
   developer certificate: **Settings → General → VPN & Device Management**.

### If the project won't open

This project was built without ever being opened in Xcode — the environment
it was written in has no Mac available, only Linux. `project.pbxproj` is
hand-written and checked as thoroughly as tooling allows without a compiler
(schema validation on the deck, brace-balance and dangling-reference checks
on the project file itself, a full unit test suite), but neither target's
`.pbxproj` entry has ever actually been opened in Xcode to confirm it loads.
The second application target (`DrinksCodex`) sharing a source folder with
the first is a meaningfully bigger hand-edit than a single-target project,
so if Xcode reports it's damaged, won't open, or a target looks wrong:

```
brew install xcodegen
xcodegen generate
```

This regenerates `Bartender101.xcodeproj` from [`project.yml`](project.yml)
and the files already on disk — nothing about the app code needs to change,
this only rebuilds the project wrapper. Re-run it any time the project file
seems out of sync with what's on disk.

## Adding a drink

Every drink is one object in
[`Shared/Resources/drinks.json`](Shared/Resources/drinks.json), shared by
both apps. Copy an existing entry as a template — here's a Negroni:

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
| `glass` | `highball`, `collins`, `copperMug`, `rocks`, `coupe`, `martini`, `wine`, `flute`, `hurricane`, `julepCup`, `shot`, `irishCoffeeMug`, `tikiMug`, `punchBowl` |
| `ice` | `cubed`, `largeCube`, `crushed`, `none` |
| `method` | `build`, `shake`, `stir`, `muddle`, `blend`, `layer` |
| `tags` | `well`, `classic`, `shot`, `tiki`, `modern` |
| ingredient `unit` | `oz`, `topWith`, `dash`, `barspoon`, `rinse`, `splash`, `muddled`, `pinch`, `optional` |

An ingredient with a non-`oz` unit can optionally carry `dashCount`,
`approxCount`, or `spoonCount` for a nicer display label (e.g. `"dashCount":
3` renders as "3 dashes"). A `topWith` ingredient is the one unit Drinks
Codex's scaler leaves alone regardless of servings — "top with tonic" is a
to-taste instruction, not a measured pour that grows linearly.

After editing, validate the file before opening Xcode:

```
node scripts/validate-drinks.js
```

This checks for duplicate ids/names, invalid enum values, missing amounts,
and that each drink's total pour is roughly sane for its family (catches,
e.g., a highball accidentally speced like a shot). It's the same check this
deck was validated with before being committed, now covering all ~180
entries across both apps.

## Architecture

```
Bartender101.xcodeproj/   Xcode 16+ project (synchronized folder groups),
                          two application targets + two test targets
project.yml               XcodeGen source of truth — see "If the project won't open"
scripts/validate-drinks.js

Shared/                   Compiled into BOTH app targets — one copy of the
                          content and logic, not two
  Resources/drinks.json   The full deck
  Models/                 Drink, Ingredient, Measure (oz/ml), ReviewState
  Data/                   DrinkLibrary (load/search), ReviewStore (persistence),
                           Scheduler (spaced-repetition math), FuzzyMatch,
                           RecipeScaler (servings math), Dilution (batch water)

Bartender101/              Bartender101-only: the study app
  Bartender101App.swift    App entry point, tab layout
  Components/              DrinkCardView (the flip card), GradeButtons
  Features/
    Home/                  Study home, due count, drill entry points
    Browse/                Searchable/filterable deck, flip-card detail view
    Review/                Spaced-repetition session
    SpeedDrill/            Timed multiple-choice drill
    Reverse/               Spec-to-name quiz
    Stats/                 Accuracy, weak drinks, per-family coverage
    Settings/              oz/ml toggle, drill timer, reset progress

DrinksCodex/                DrinksCodex-only: the reference app
  DrinksCodexApp.swift      App entry point, tab layout
  Features/
    Search/                 Searchable/filterable encyclopedia
    DrinkDetail/             Full spec + the scaling panel (servings,
                              presets, batch mode, unit toggle)
    Settings/                Default unit preference

Bartender101Tests/          DrinkLibraryTests, SchedulerTests, MeasureTests
DrinksCodexTests/           RecipeScalerTests, DilutionTests
```

`Scheduler.swift`, `FuzzyMatch.swift`, `RecipeScaler.swift`, and
`Dilution.swift` are all written as pure functions with no SwiftUI or
storage dependency — the intent is that a future web version can port this
logic near-verbatim rather than redesigning it.

Bartender101's progress is persisted as a single JSON file in Application
Support (via `ReviewStore`), not SwiftData — deliberately, so the
persistence layer stays something you can inspect and reason about directly,
and so the same `[String: ReviewState]` shape maps cleanly onto
`localStorage` for a web build later. Drinks Codex has no progress to
persist; its only stored state is a unit preference in `UserDefaults`.

## Bartender101 (the study app)

- **Spaced Review** — cards you miss come back sooner, cards you nail come
  back later. The standard spaced-repetition trick for making a deck stick
  with the least total study time.
- **Speed Drill** — a name on screen, four ingredient lists, a clock. Trains
  actual recall speed, not just eventual recall.
- **Name That Drink** — the reverse direction: shown a spec, you name the
  drink. This is the direction you need when a guest describes what they
  want instead of asking for it by name.

## Drinks Codex (the reference app)

A fast, searchable reference for the drink you don't have memorized yet,
built around one core mechanic: resizing a recipe on the spot.

- **Servings multiplier** — every ingredient scales live as you step the
  count up or down.
- **Format presets** — Shot / Single / Double just set the multiplier to
  0.5 / 1 / 2. There's no separate "double" recipe path, so a preset can
  never drift out of sync with the stepper.
- **Batch/pitcher mode** — pre-mixing several servings skips the dilution a
  drink would normally get from being shaken or stirred to order, so this
  adds a calculated water line based on the drink's method (stir, shake,
  muddle each dilute differently; built and blended drinks take none).
- **oz⇄ml toggle** — applies to the scaled amount, not just the base recipe.

## Not built yet

Deliberately out of scope for this pass, but the architecture doesn't block
them:

- **Ticket Rush** — a game mode where orders arrive on a timer and you build
  drinks against the clock. The natural next step toward a web game;
  `Scheduler` and the deck already support it.
- **Custom cards** — an in-app editor for house specials, rather than
  hand-editing `drinks.json`.
- **Photos per drink** — a content/asset task orthogonal to the scaling
  feature Drinks Codex shipped with.
- **The web build itself** — `Shared/Resources/drinks.json` and the
  pure-function data layer are the pieces designed to cross over directly.
