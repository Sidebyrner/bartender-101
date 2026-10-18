#!/usr/bin/env node
// Builds the builder's reference data from Bar Assistant's open recipe set
// (https://github.com/bar-assistant/data, MIT). Run by hand against a local
// clone — the clone itself is never committed:
//
//   git clone --depth 1 https://github.com/bar-assistant/data.git /tmp/ba
//   node scripts/import-reference.js /tmp/ba
//
// Writes three files to Shared/Resources:
//   reference_drinks.json  recipes normalized to the Drink schema (oz, app
//                          units, app ingredient names, a family)
//   pairings.json          for each ingredient, the ones recipes most often
//                          use with it (over reference + deck drinks)
//   family_profiles.json   per family, the typical share of the drink's
//                          volume each flavor role takes
//
// Only specs are copied — names, amounts, method, glass, garnish, ABV, tags,
// riff parent, source link. Descriptions and instructions are left out.
// Recipes with an ingredient the catalog can't name are dropped, and the
// report lists those names so aliases can be added below.

const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..", "Shared", "Resources");
const baRoot = process.argv[2];
if (!baRoot) {
  console.error("usage: node scripts/import-reference.js <bar-assistant-data clone>");
  process.exit(1);
}

// Same folding as IngredientIndex.normalize: case, accents, punctuation.
function normalize(s) {
  return s.normalize("NFKD").replace(/[̀-ͯ]/g, "").toLowerCase()
    .replace(/[^a-z0-9]+/g, " ").trim();
}

const catalog = JSON.parse(fs.readFileSync(path.join(ROOT, "ingredients.json"), "utf8"));
const deck = JSON.parse(fs.readFileSync(path.join(ROOT, "drinks.json"), "utf8"));

const byKey = new Map();
for (const c of catalog) {
  for (const k of [c.name, ...(c.aliases || [])]) {
    if (!byKey.has(normalize(k))) byKey.set(normalize(k), c);
  }
}

// Bar Assistant name → catalog name, for names the catalog's aliases don't
// already cover.
const ALIASES = {
  "angostura aromatic bitters": "Angostura bitters",
  "bitters": "Angostura bitters",
  "bourbon whiskey": "Bourbon",
  "tequila blanco": "Blanco tequila",
  "tequila reposado": "Reposado tequila",
  "grenadine syrup": "Grenadine",
  "orgeat syrup": "Orgeat",
  "scotch whiskey": "Scotch",
  "blended scotch whisky": "Blended Scotch",
  "islay scotch whiskey": "Islay single malt Scotch",
  "cask proof whiskey": "Whiskey",
  "japanese whiskey": "Japanese whisky",
  "passionfruit syrup": "Passion fruit syrup",
  "passionfruit puree": "Passion fruit purée",
  "peychauds bitters": "Peychaud's bitters",
  "vermouth bianco": "Blanc vermouth",
  "amaro averna": "Averna",
  "amaro ramazzotti": "Ramazzotti",
  "rhum agricole": "Rhum agricole blanc",
  "cocchi aperitivo americano": "Cocchi Americano",
  "brown rum": "Aged rum",
  "barbados rum": "Aged rum",
  "rum": "White rum",
  // The deck says "White rum"; keep one name so pairings and matches agree.
  "light rum": "White rum",
  "white rum": "White rum",
  "pear brandy williams": "Pear brandy",
  "creme de menthe": "Green crème de menthe",
  "creme de cacao white": "White crème de cacao",
  "creme de cacao dark": "Crème de cacao",
  "angostura cocoa bitters": "Chocolate bitters",
  "egg": "Whole egg",
  "peach liqueur": "Crème de pêche",
  "baileys irish cream": "Irish cream",
  "fino": "Fino sherry",
  "manzanilla sherry": "Fino sherry",
  "apple cider": "Hard cider",
  "grape brandy": "Brandy",
  "plum brandy": "Brandy",
  "pimm s 1": "Pimm's No. 1",
  "lemon soda": "Lemon-lime soda",
  "tea": "Iced tea",
  "chilli pepper": "Jalapeño slices",
  "ginger": "Ginger slices",
  "grapefruit": "Grapefruit juice",
  "lillet rose": "Lillet Blanc",
  "chinola passionfruit": "Passion fruit purée",
  "tangerine juice": "Orange juice",
  "gentian liqueur": "Suze",
  "salers": "Suze",
  "domaine la boheme gentiane extra bitter aperitif": "Suze",
  "pineapple syrup": "Pineapple gum syrup",
  "amaro meletti": "Amaro",
  "amaro lazzaroni": "Amaro",
  "amaro ciociaro": "Amaro",
  "amaro sibilla": "Amaro",
};

// Lines that aren't ingredients for our purposes.
const SKIP = new Set(["water", "crushed ice", "ice"]);

function resolve(name) {
  const key = normalize(name);
  if (ALIASES[key]) return byKey.get(normalize(ALIASES[key]));
  return byKey.get(key);
}

const ROLE_BY_CATEGORY = {
  spirits: "spirit", liqueurs: "modifier", vermouthAmari: "modifier", bitters: "modifier",
  citrus: "sour", syrups: "sweet", juices: "lengthener", mixers: "lengthener",
  wineBeer: "lengthener", dairyEgg: "dairy", herbsFruit: "accent", seasoning: "other",
};
const ACCENT_UNITS = new Set(["dash", "rinse", "barspoon", "pinch", "muddled"]);
const AMOUNTLESS_UNITS = new Set(["dash", "barspoon", "rinse", "muddled", "pinch", "optional"]);

function roleOf(line) {
  if (ACCENT_UNITS.has(line.unit)) return "accent";
  const entry = resolve(line.name);
  return entry ? ROLE_BY_CATEGORY[entry.category] : "other";
}

// Rounds to the nearest eighth of an ounce, like Measure.ozFraction.
const eighth = (oz) => Math.max(0.125, Math.round(oz * 8) / 8);

// One Bar Assistant ingredient line → an app Ingredient, or a reason it can't be.
function convertLine(ing, entry) {
  const amount = typeof ing.amount === "number" ? ing.amount : null;
  const units = (ing.units || "").toLowerCase();
  const name = entry.name;
  const base = { name, amountOz: null, dashCount: null, approxCount: null, spoonCount: null };
  switch (units) {
    case "ml": return amount ? { ...base, unit: "oz", amountOz: eighth(amount / 30) } : null;
    case "cl": return amount ? { ...base, unit: "oz", amountOz: eighth(amount / 3) } : null;
    case "oz": case "shot": return amount ? { ...base, unit: "oz", amountOz: eighth(units === "shot" ? amount * 1.5 : amount) } : null;
    case "dash": case "dashes":
      return { ...base, unit: "dash", dashCount: Math.max(1, Math.round(amount || 1)) };
    case "drops":
      return { ...base, unit: "dash", dashCount: Math.max(1, Math.round((amount || 1) / 4)) };
    case "barspoon": case "teaspoon": case "tsp":
      return { ...base, unit: "barspoon", spoonCount: Math.max(1, Math.round(amount || 1)) };
    case "tablespoon":
      return { ...base, unit: "oz", amountOz: eighth((amount || 1) * 0.5) };
    case "topup": return { ...base, unit: "topWith", amountOz: 3 };
    case "splash": return { ...base, unit: "splash", amountOz: 0.5 };
    case "pinch": return { ...base, unit: "pinch" };
  }
  // Counted things: herbs and fruit get muddled, seasoning is a pinch, and a
  // whole egg is about an ounce and a half.
  if (entry.category === "herbsFruit") {
    return { ...base, unit: "muddled", approxCount: amount ? Math.max(1, Math.round(amount)) : null };
  }
  if (entry.category === "seasoning") return { ...base, unit: "pinch" };
  if (entry.category === "dairyEgg" && /egg/i.test(name)) {
    return { ...base, unit: "oz", amountOz: name === "Whole egg" ? 1.5 : 1 };
  }
  return null;
}

const GLASS = {
  lowball: "rocks", highball: "highball", coupe: "coupe", cocktail: "martini",
  "nick and nora": "coupe", wine: "wine", hurricane: "hurricane", "glass mug": "irishCoffeeMug",
  champagne: "flute", tiki: "tikiMug", fizzio: "highball", julep: "julepCup", shot: "shot",
  absinthe: "rocks", "copper mug": "copperMug", margarita: "coupe",
};
const METHOD = { shake: "shake", stir: "stir", build: "build", blend: "blend", muddle: "muddle", layer: "layer" };

// Mirrors DrinkFamily.ozBand / OZ_BANDS in validate-drinks.js.
const OZ_BANDS = {
  highball: [2, 8], mule: [2, 8], sour: [1.5, 5], oldFashioned: [1.5, 3.5],
  martini: [1.5, 4.5], manhattan: [1.5, 4.5], spritz: [2, 6.5], tiki: [2, 8],
  muddled: [1.5, 8], cream: [2, 4], shot: [1, 3.5], misc: [1.5, 12],
};

// The deck's own habits decide these: Negronis are manhattans, fizzes and
// egg sours are sours, Americanos and French 75s are spritzes.
function familyFor(drink, tags) {
  const has = (t) => tags.includes(t);
  const oz = {};
  const roles = new Set();
  const names = drink.ingredients.map((i) => i.name);
  for (const line of drink.ingredients) {
    const role = roleOf(line);
    roles.add(role);
    if (line.amountOz) oz[role] = (oz[role] || 0) + line.amountOz;
  }
  const long = oz.lengthener || 0;
  const sparkling = names.some((n) => /champagne|prosecco|cava|sparkling/i.test(n));
  const creamy = names.some((n) => /cream|milk|ice cream/i.test(n) && !/cream soda|crème|cream of coconut/i.test(n));

  if (has("Tiki")) return "tiki";
  if (has("Spritz") || sparkling) return "spritz";
  if (creamy) return "cream";
  if (drink.method === "muddle" || has("Mojito") || has("Julep") || has("Smash")) return "muddled";
  if (names.includes("Ginger beer") || has("Mule")) return "mule";
  if (drink.glass === "shot") return "shot";
  if (roles.has("sour")) {
    if (long > 2 && drink.method !== "shake") return "highball";
    if (long > 3) return "highball";
    return "sour";
  }
  if (long >= 2) return "highball";
  if (roles.has("modifier") && (oz.modifier || 0) >= 0.5 && drink.method !== "shake") {
    const vermouthOnly = names.every((n) => !/sweet vermouth|punt e mes|campari|amaro|averna|cynar|fernet|aperol|braulio|ramazzotti|bonal/i.test(n));
    const dryish = names.some((n) => /dry vermouth|blanc vermouth|lillet|cocchi|fino/i.test(n));
    return vermouthOnly && dryish ? "martini" : "manhattan";
  }
  if (roles.has("spirit") && (oz.modifier || 0) < 0.5 && drink.method !== "shake") return "oldFashioned";
  return "misc";
}

function iceFor(glass, method) {
  if (glass === "tikiMug" || glass === "julepCup") return "crushed";
  if (glass === "coupe" || glass === "martini" || glass === "flute" || glass === "shot" || glass === "irishCoffeeMug") return "none";
  if (glass === "rocks" && method === "stir") return "largeCube";
  return "cubed";
}

const slug = (s) => normalize(s).replace(/ /g, "-");

// --- Convert --------------------------------------------------------------

const deckNames = new Set(deck.map((d) => normalize(d.name)));
const cocktailsDir = path.join(baRoot, "data", "cocktails");
const raw = fs.readdirSync(cocktailsDir)
  .filter((d) => fs.existsSync(path.join(cocktailsDir, d, "data.json")))
  .map((d) => JSON.parse(fs.readFileSync(path.join(cocktailsDir, d, "data.json"), "utf8")));
const nameByBAID = new Map(raw.map((r) => [r._id, r.name]));

const unknown = new Map();
const dropped = { unknownIngredient: 0, unit: 0, inDeck: 0, band: 0, empty: 0 };
const reference = [];

for (const r of raw) {
  if (deckNames.has(normalize(r.name))) { dropped.inDeck++; continue; }
  const lines = [];
  let ok = true;
  for (const ing of r.ingredients || []) {
    if (ing.optional) continue;
    if (SKIP.has(normalize(ing.name))) continue;
    const entry = resolve(ing.name);
    if (!entry) {
      unknown.set(ing.name, (unknown.get(ing.name) || 0) + 1);
      ok = false; dropped.unknownIngredient++; break;
    }
    const line = convertLine(ing, entry);
    if (!line) { ok = false; dropped.unit++; break; }
    // Two lines naming the same bottle (split bases) are merged.
    const same = lines.find((l) => l.name === line.name && l.unit === line.unit);
    if (same && same.amountOz != null && line.amountOz != null) same.amountOz += line.amountOz;
    else if (!same) lines.push(line);
  }
  if (!ok) continue;
  if (lines.length === 0) { dropped.empty++; continue; }

  const glass = GLASS[(r.glass || "").toLowerCase()] || "rocks";
  const method = METHOD[(r.method || "").toLowerCase()] || "build";
  const drink = {
    id: `ref-${slug(r.name)}`,
    name: r.name.trim(),
    family: "misc",
    glass,
    ice: iceFor(glass, method),
    method,
    ingredients: lines.map(stripNulls),
    garnish: (r.garnish || "").replace(/^garnish (with )?/i, "").replace(/\.$/, "").trim(),
    tags: (r.tags || []).filter((t) => !/^(the unforgettables|contemporary classics|new era drinks)$/i.test(t)),
    abv: typeof r.abv === "number" && r.abv > 0 ? Math.round(r.abv * 10) / 10 : null,
    parent: r.parent_cocktail_id ? nameByBAID.get(r.parent_cocktail_id) || null : null,
    source: typeof r.source === "string" && /^https?:/.test(r.source) ? r.source : null,
  };
  drink.family = familyFor(drink, r.tags || []);
  const total = lines.reduce((s, l) => s + (l.amountOz || 0), 0);
  const inBand = (f) => total >= OZ_BANDS[f][0] && total <= OZ_BANDS[f][1];
  if (!inBand(drink.family)) {
    if (inBand("misc")) drink.family = "misc";
    else { dropped.band++; continue; }
  }
  reference.push(drink);
}

function stripNulls(line) {
  const out = {};
  for (const [k, v] of Object.entries(line)) if (v !== null) out[k] = v;
  return out;
}

// Unique ids and names (Bar Assistant has a few near-duplicates).
const seen = new Set();
const unique = reference.filter((d) => (seen.has(d.id) ? false : (seen.add(d.id), true)));
unique.sort((a, b) => a.name.localeCompare(b.name));

// --- Validate -------------------------------------------------------------

const UNITS = ["oz", "topWith", "dash", "barspoon", "rinse", "splash", "muddled", "pinch", "optional"];
const errors = [];
for (const d of unique) {
  for (const l of d.ingredients) {
    if (!UNITS.includes(l.unit)) errors.push(`${d.id}: bad unit ${l.unit}`);
    if (!AMOUNTLESS_UNITS.has(l.unit) && !(l.amountOz > 0)) errors.push(`${d.id}: ${l.name} needs amountOz`);
    if (!resolve(l.name)) errors.push(`${d.id}: ${l.name} not in catalog`);
  }
  if (!OZ_BANDS[d.family]) errors.push(`${d.id}: bad family ${d.family}`);
}

// --- Pairings (deck + reference) -----------------------------------------

const corpus = [...deck, ...unique].map((d) => [...new Set(d.ingredients
  .map((l) => resolve(l.name)?.name)
  .filter(Boolean))]);
const N = corpus.length;
const single = new Map();
const pair = new Map();
for (const set of corpus) {
  for (const a of set) single.set(a, (single.get(a) || 0) + 1);
  for (const a of set) for (const b of set) if (a !== b) {
    const k = `${a}\u0000${b}`;
    pair.set(k, (pair.get(k) || 0) + 1);
  }
}
const MIN_TOGETHER = 3;
const partners = {};
for (const [k, together] of pair) {
  if (together < MIN_TOGETHER) continue;
  const [a, b] = k.split("\u0000");
  const lift = (together * N) / (single.get(a) * single.get(b));
  if (lift <= 1) continue;
  // How often b shows up when a does, weighted by how much more than
  // chance: lift alone favors rare curiosities, frequency alone says
  // "simple syrup" to everything.
  const score = (together / single.get(a)) * Math.log2(lift);
  (partners[a] = partners[a] || []).push({ name: b, together, score: Math.round(score * 1000) / 1000 });
}
const pairings = {};
for (const a of Object.keys(partners).sort()) {
  pairings[a] = {
    recipes: single.get(a),
    partners: partners[a].sort((x, y) => y.score - x.score).slice(0, 15),
  };
}

// --- Family profiles (deck + reference) ----------------------------------

const ROLES = ["spirit", "modifier", "sour", "sweet", "dairy", "lengthener"];
const sharesByFamily = {};
for (const d of [...deck, ...unique]) {
  const oz = {};
  let total = 0;
  for (const l of d.ingredients) {
    if (!(l.amountOz > 0)) continue;
    const role = roleOf(l);
    oz[role] = (oz[role] || 0) + l.amountOz;
    total += l.amountOz;
  }
  if (total <= 0) continue;
  (sharesByFamily[d.family] = sharesByFamily[d.family] || []).push(
    Object.fromEntries(ROLES.map((r) => [r, (oz[r] || 0) / total])));
}
function quantile(sorted, q) {
  const i = (sorted.length - 1) * q;
  const lo = Math.floor(i), hi = Math.ceil(i);
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (i - lo);
}
const r3 = (x) => Math.round(x * 1000) / 1000;
const profiles = {};
for (const [family, rows] of Object.entries(sharesByFamily)) {
  profiles[family] = { drinks: rows.length, roles: {} };
  for (const role of ROLES) {
    const v = rows.map((row) => row[role]).sort((a, b) => a - b);
    profiles[family].roles[role] = { low: r3(quantile(v, 0.25)), median: r3(quantile(v, 0.5)), high: r3(quantile(v, 0.75)) };
  }
}

// --- Report & write -------------------------------------------------------

const famCounts = {};
for (const d of unique) famCounts[d.family] = (famCounts[d.family] || 0) + 1;
console.log(`Read ${raw.length} Bar Assistant recipes; kept ${unique.length}.`);
console.log("Dropped:", dropped);
console.log("Families:", famCounts);
console.log(`Pairings for ${Object.keys(pairings).length} ingredients; profiles for ${Object.keys(profiles).length} families.`);
const misses = [...unknown].sort((a, b) => b[1] - a[1]);
if (misses.length) {
  console.log(`\n${misses.length} unmatched ingredient names (add an alias to keep these recipes):`);
  for (const [n, c] of misses.slice(0, 25)) console.log(`  ${c}× ${n}`);
}
if (errors.length) {
  console.error(`\nFAILED: ${errors.length} problem(s)`);
  for (const e of errors) console.error(" -", e);
  process.exit(1);
}

const write = (file, value) => fs.writeFileSync(path.join(ROOT, file), JSON.stringify(value, null, 1) + "\n");
write("reference_drinks.json", unique);
write("pairings.json", pairings);
write("family_profiles.json", profiles);
console.log("\nWrote reference_drinks.json, pairings.json, family_profiles.json");
