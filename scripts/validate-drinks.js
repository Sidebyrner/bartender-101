#!/usr/bin/env node
// Validates Shared/Resources/drinks.json against the schema the Swift
// models (Models/Drink.swift, Models/Ingredient.swift) decode. Run with:
//   node scripts/validate-drinks.js
// Exits non-zero and prints every problem found on failure.

const fs = require("fs");
const path = require("path");

const DRINKS_PATH = path.join(__dirname, "..", "Shared", "Resources", "drinks.json");

const FAMILIES = ["highball", "mule", "sour", "oldFashioned", "martini", "manhattan",
  "spritz", "tiki", "muddled", "cream", "shot", "misc"];
const GLASSES = ["highball", "collins", "copperMug", "rocks", "coupe", "martini",
  "wine", "flute", "hurricane", "julepCup", "shot", "irishCoffeeMug", "tikiMug", "punchBowl"];
const ICE = ["cubed", "largeCube", "crushed", "none"];
const METHODS = ["build", "shake", "stir", "muddle", "blend", "layer"];
const UNITS = ["oz", "topWith", "dash", "barspoon", "rinse", "splash", "muddled",
  "pinch", "optional"];
const TAGS = ["well", "classic", "shot", "tiki", "modern"];

// Units that legitimately carry no amountOz (garnish/seasoning-style additions).
const AMOUNTLESS_UNITS = new Set(["dash", "barspoon", "rinse", "muddled", "pinch", "optional"]);

// Rough total-oz sanity bands per family, catching pours that are obviously
// wrong in scale (e.g. a highball speced like a shot). Ranges are generous —
// this is a smoke check, not a style guide.
const OZ_BANDS = {
  highball: [2, 8], mule: [2, 8], sour: [1.5, 5], oldFashioned: [1.5, 3.5],
  martini: [1.5, 4.5], manhattan: [1.5, 4.5], spritz: [2, 6.5], tiki: [2, 8],
  muddled: [1.5, 8], cream: [2, 4], shot: [1, 3.5], misc: [1.5, 12],
};

function fail(msg) { errors.push(msg); }

const errors = [];
const raw = fs.readFileSync(DRINKS_PATH, "utf8");
let drinks;
try {
  drinks = JSON.parse(raw);
} catch (e) {
  console.error("drinks.json is not valid JSON:", e.message);
  process.exit(1);
}

if (!Array.isArray(drinks) || drinks.length === 0) {
  fail("drinks.json must be a non-empty array");
}

const seenIds = new Set();
const seenNames = new Set();

for (const d of drinks) {
  const where = `[${d.id || d.name || "?"}]`;

  if (!d.id || typeof d.id !== "string") fail(`${where} missing/invalid id`);
  else if (seenIds.has(d.id)) fail(`${where} duplicate id`);
  else seenIds.add(d.id);

  if (!d.name || typeof d.name !== "string") fail(`${where} missing/invalid name`);
  else if (seenNames.has(d.name)) fail(`${where} duplicate name "${d.name}"`);
  else seenNames.add(d.name);

  if (!FAMILIES.includes(d.family)) fail(`${where} invalid family "${d.family}"`);
  if (!GLASSES.includes(d.glass)) fail(`${where} invalid glass "${d.glass}"`);
  if (!ICE.includes(d.ice)) fail(`${where} invalid ice "${d.ice}"`);
  if (!METHODS.includes(d.method)) fail(`${where} invalid method "${d.method}"`);

  if (typeof d.difficulty !== "number" || d.difficulty < 1 || d.difficulty > 3) {
    fail(`${where} difficulty must be 1-3`);
  }

  if (!Array.isArray(d.tags) || d.tags.length === 0) fail(`${where} needs at least one tag`);
  else for (const t of d.tags) if (!TAGS.includes(t)) fail(`${where} invalid tag "${t}"`);

  if (!Array.isArray(d.ingredients) || d.ingredients.length === 0) {
    fail(`${where} must have at least one ingredient`);
  } else {
    let totalOz = 0;
    for (const ing of d.ingredients) {
      if (!ing.name || typeof ing.name !== "string") fail(`${where} ingredient missing name`);
      if (!UNITS.includes(ing.unit)) fail(`${where} "${ing.name}" invalid unit "${ing.unit}"`);
      const needsAmount = !AMOUNTLESS_UNITS.has(ing.unit);
      if (needsAmount && (typeof ing.amountOz !== "number" || ing.amountOz <= 0)) {
        fail(`${where} "${ing.name}" (unit ${ing.unit}) needs a positive amountOz`);
      }
      if (typeof ing.amountOz === "number") totalOz += ing.amountOz;
    }
    const band = OZ_BANDS[d.family];
    if (band && (totalOz < band[0] || totalOz > band[1])) {
      fail(`${where} total measured oz ${totalOz.toFixed(2)} outside expected ${band[0]}-${band[1]} for family "${d.family}"`);
    }
  }

  if (!d.garnish && d.garnish !== "None" && d.garnish !== null) {
    fail(`${where} garnish should be a string or "None"`);
  }
  if (!d.notes || typeof d.notes !== "string" || d.notes.length < 10) {
    fail(`${where} notes missing or too short`);
  }
}

if (errors.length > 0) {
  console.error(`FAILED: ${errors.length} problem(s) in drinks.json\n`);
  for (const e of errors) console.error(" -", e);
  process.exit(1);
}

console.log(`OK: ${drinks.length} drinks validated (unique ids, valid enums, ingredient amounts, oz sanity).`);
