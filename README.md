# Bartender 101

A native iOS app for both halves of learning to bartend: looking a recipe up
fast mid-shift — scaled to whatever size it needs to be — and memorizing
recipes before one — plus a place to invent your own. One app, one ~180-drink
deck, five tabs:

- **Search** — the full deck, searchable by name or ingredient and filterable
  by tag and family. Tapping a drink opens its recipe page, built around
  resizing it on the spot: a servings multiplier, shot/single/double presets,
  a batch/pitcher mode that accounts for the dilution a big batch won't get
  from being shaken or stirred to order, and an oz⇄ml toggle. A **Flashcard**
  button flips the same drink into a study card.
- **Study** — three drills (Spaced Review, Speed Drill, Name That Drink) for
  drilling recipes into muscle memory.
- **Build** — invent house drinks: start from a family's classic ratio or riff
  on any drink, watch a live balance meter, and move each idea across a
  testing board (Idea → Testing → Dialed In → On the Menu) with a tasting log.
- **Stats** — tonight's shift and past nights (drinks logged with **Made it**),
  plus study accuracy, weak drinks, per-family coverage.
- **Settings** — oz/ml, speed-drill timer, reset progress, delete house drinks.

Everything reads [`Shared/Resources/drinks.json`](Shared/Resources/drinks.json)
and the pure model/data layer in [`Shared/`](Shared), so a future web build
has one file and one set of pure functions to port.

Built as plain SwiftUI, iOS 17+, zero third-party dependencies.

> Drinks Codex used to be a separate app target in this repo. It was merged
> into Bartender 101 so there's one app to open instead of two.

## Getting started

1. Clone the repo and run `xcodegen generate` (`brew install xcodegen` if
   needed) to create `Bartender101.xcodeproj` from [`project.yml`](project.yml).
2. Open `Bartender101.xcodeproj` in Xcode 16 or later. There's one scheme:
   **Bartender101**.
3. Press **⌘U** first — the test suite is the fastest signal that the deck,
   models, and math are intact.
4. Press **⌘R** to run in the iOS Simulator.

No signing setup, no Swift Package dependencies to resolve.

### Running on your own iPhone

1. In Xcode, select your iPhone as the run destination (connect it via
   cable, or over Wi-Fi once paired once).
2. Select the project in the navigator → the `Bartender101` target →
   **Signing & Capabilities** → choose your Apple ID under **Team**. A free
   Apple ID works; no paid developer account needed to run your own app on
   your own device.
3. Change **Bundle Identifier** to something unique to you, e.g.
   `com.yourname.Bartender101` — the default (`com.bartender101.Bartender101`)
   will collide if anyone else has built this.
4. Press **⌘R**. The first time, your iPhone will ask you to trust the
   developer certificate: **Settings → General → VPN & Device Management**.

### If the project looks out of sync

`project.yml` is the source of truth. If Xcode reports the project is
damaged, or a file on disk is missing from it, regenerate:

```
xcodegen generate
```

This only rebuilds the project wrapper; nothing about the app code changes.

## Adding a drink

Every drink is one object in
[`Shared/Resources/drinks.json`](Shared/Resources/drinks.json). Copy an existing entry as a template — here's a Negroni:

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
| `tags` | `well`, `classic`, `shot`, `tiki`, `modern` (`house` is reserved for drinks made in Build) |
| ingredient `unit` | `oz`, `topWith`, `dash`, `barspoon`, `rinse`, `splash`, `muddled`, `pinch`, `optional` |

An ingredient with a non-`oz` unit can optionally carry `dashCount`,
`approxCount`, or `spoonCount` for a nicer display label (e.g. `"dashCount":
3` renders as "3 dashes"). A `topWith` ingredient is the one unit the
recipe scaler leaves alone regardless of servings — "top with tonic" is a
to-taste instruction, not a measured pour that grows linearly.

After editing, validate the file before opening Xcode:

```
node scripts/validate-drinks.js
```

Every ingredient name must also be in
[`Shared/Resources/ingredients.json`](Shared/Resources/ingredients.json) —
add a new entry (with a `category` and any `aliases`) or an alias on an
existing one. The script checks that too.

This checks for duplicate ids/names, invalid enum values, missing amounts,
and that each drink's total pour is roughly sane for its family (catches,
e.g., a highball accidentally speced like a shot). It's the same check this
deck was validated with before being committed, now covering all ~180
entries.

## Architecture

```
Bartender101.xcodeproj/   Generated by XcodeGen — one app target + one test target
project.yml               XcodeGen source of truth
scripts/validate-drinks.js

Shared/                   Content and pure logic, no SwiftUI views
  Resources/drinks.json   The full deck
  Resources/ingredients.json  The builder's ingredient catalog
  Models/                 Drink, Ingredient, Measure (oz/ml), ReviewState, MadeDrink,
                           CustomDrink (house drinks + TestStage, TastingNote),
                           CatalogIngredient (+ IngredientCategory)
  Data/                   DrinkLibrary (load/search), ReviewStore (persistence),
                           Scheduler (spaced-repetition math), FuzzyMatch,
                           RecipeScaler (servings math), Dilution (batch water),
                           PourOrder, BuildSteps, ShiftLog + ShiftLogStore,
                           CustomDrinkStore, DrinkTemplates, DrinkBalance,
                           IngredientIndex (search), IngredientCatalog,
                           IngredientChecks (unit + duplicate safeguards)

Bartender101/              The app
  Bartender101App.swift    App entry point, tab layout (Search · Study · Build · Stats · Settings)
  Components/              DrinkCardView (the flip card), GradeButtons
  Features/
    Search/                Searchable/filterable deck
    DrinkDetail/           Recipe page + scaling panel (servings, presets,
                            batch mode, unit toggle), FlashcardView
    Study/                 Study home, due count, drill entry points
      Review/              Spaced-repetition session
      SpeedDrill/          Timed multiple-choice drill
      Reverse/             Spec-to-name quiz
    Build/                 Testing board, drink builder, ingredient picker, balance meter,
                            house-drink panel (stage + tasting log)
    Stats/                 Shift log (tonight, history, per-night detail),
                            accuracy, weak drinks, per-family coverage
    Settings/              oz/ml toggle, drill timer, reset progress

Bartender101Tests/         DrinkLibraryTests, SchedulerTests, MeasureTests,
                           RecipeScalerTests, DilutionTests, PourOrderTests,
                           BuildStepsTests, ShiftLogTests, CustomDrinkStoreTests,
                           DrinkBalanceTests, IngredientCatalogTests,
                           IngredientChecksTests
```

`Scheduler.swift`, `FuzzyMatch.swift`, `RecipeScaler.swift`, and
`Dilution.swift` are all written as pure functions with no SwiftUI or
storage dependency — the intent is that a future web version can port this
logic near-verbatim rather than redesigning it.

Study progress is persisted as a single JSON file in Application Support
(via `ReviewStore`), not SwiftData — deliberately, so the persistence layer
stays something you can inspect and reason about directly, and so the same
`[String: ReviewState]` shape maps cleanly onto `localStorage` for a web
build later. Preferences (unit, drill timer) live in `UserDefaults`.

## Looking a drink up

A fast reference for the drink you don't have memorized yet, built around
one core mechanic: resizing a recipe on the spot.

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
- **Flashcard** — flips the drink you're looking at into a study card, so a
  lookup can double as a quick self-quiz.
- **Bartending Mode** — big text and 56pt buttons on Search and recipe
  pages, toggled from Search's **Bar Mode** button. Recipe pages read in the
  order you make the drink (glass and ice → pours, cheapest first → method →
  top → garnish) and keep the screen awake.

## Logging a shift

Tap **Made it** at the bottom of a recipe page after making the drink. It's
logged with the servings, batch setting, and unit on screen at that moment
(Undo is offered for a few seconds). Stats shows tonight's count and a
history of past nights — per-drink tallies, total servings and volume, and
every drink with its time and scale. A night runs until 4 AM, so a 1:30 AM
drink counts toward the evening shift. The log is a JSON file in Application
Support (`ShiftLogStore`); clear it from Settings.

## Building house drinks

The **Build** tab gets an idea out of your head and into the glass.

- **Start somewhere** — tap **+** and pick a family's classic ratio (a sour
  starts at 2 : ¾ : ¾, a Manhattan at 2 : 1 + bitters), riff on any drink in
  the deck, or start blank. Any recipe page also has **Riff on this** in its
  toolbar.
- **Ingredient picker** — ingredients are picked, not typed into the row.
  **Add ingredient** (or tapping any row) opens a full-screen picker over a
  curated catalog (`Shared/Resources/ingredients.json`, ~275 bar staples with
  categories and aliases like "OJ" and "Kahlúa"). Search forgives typos and
  accents ("lime jiuce", "creme de cassis"); an empty search shows recents and
  every shelf. Picking fills in the ingredient's usual pour, learned from the
  deck (lime juice → ¾ oz, Angostura → 2 dashes, soda → top with).
  - **Swapping** a row asks **Replace** or **Back** and says what happens to
    the pour. Template stand-ins ("Choose a spirit") open on the right shelf
    and fill in without asking.
  - **Already in the drink?** The picker offers **Combine**, **Add Anyway**,
    or **Back**, and the builder flags any repeated row with **Combine**.
  - **Not on the shelf?** "Did you mean…" comes first; adding a new
    ingredient asks which shelf it belongs on and saves it for next time.
    Text that's only the start of a known name can't be added as new.
  - **Rows** have one-tap amount chips, a unit menu, and a warning with a
    one-tap **Fix** for units that don't fit (2 oz of bitters, "top with"
    gin, muddled soda). Deleting a row offers **Undo**.
  - A drink can't go **On the Menu** while a template stand-in is left in it.
- **Balance meter** — pinned above the editor, it splits the pour into
  spirit, liqueur, sour, sweet, and long, shows the total, and flags rules of
  thumb: a pour too big or small for its family, citrus or cream that's
  stirred, a sour with no citrus, citrus with nothing sweet. Roles come from
  the same word lists as `PourOrder`; the heuristics live in `DrinkBalance`
  and are tested to stay quiet on the classics in the deck.
- **Testing board** — one column per stage: Idea, Testing, Dialed In, On the
  Menu, Shelved. Drag a card between columns, or long-press it for **Move
  To**, **Duplicate as New Version**, and **Delete**. Cards show labels
  ("summer menu"), tasting count, and average rating.
- **Recipe page** — a house drink opens the normal recipe page (scaling,
  batch water, pour order, **Made it**) with its stage, labels, and a
  **tasting log** of dated notes with 1–5 star ratings on top. Edit it from
  the toolbar menu.
- **On the Menu** — only drinks at this stage join the deck: Search (under
  the **House** filter), Study drills, and Stats. Moving a drink there needs a
  unique name and complete amounts, the same basics the deck validator checks.

House drinks are a JSON file in Application Support (`CustomDrinkStore`);
clear them from Settings.

## Studying

- **Spaced Review** — cards you miss come back sooner, cards you nail come
  back later. The standard spaced-repetition trick for making a deck stick
  with the least total study time.
- **Speed Drill** — a name on screen, four ingredient lists, a clock. Trains
  actual recall speed, not just eventual recall.
- **Name That Drink** — the reverse direction: shown a spec, you name the
  drink. This is the direction you need when a guest describes what they
  want instead of asking for it by name.

## Not built yet

Deliberately out of scope for this pass, but the architecture doesn't block
them:

- **Ticket Rush** — a game mode where orders arrive on a timer and you build
  drinks against the clock. The natural next step toward a web game;
  `Scheduler` and the deck already support it.
- **Photos per drink** — a content/asset task orthogonal to the recipe
  scaler.
- **The web build itself** — `Shared/Resources/drinks.json` and the
  pure-function data layer are the pieces designed to cross over directly.
