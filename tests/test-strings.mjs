// Every language has to answer for every key. A table that quietly falls back
// to English is a table nobody notices is half-empty.
import { readFileSync, readdirSync } from "node:fs"
import { fileURLToPath } from "node:url"
import { dirname, join } from "node:path"
import test from "node:test"
import assert from "node:assert/strict"

const here = dirname(fileURLToPath(import.meta.url))
const load = (name, exports) => {
  const source = readFileSync(join(here, "..", name), "utf8").replace(/^\.pragma library\s*/, "")
  return new Function(`${source}; return {${exports}}`)()
}

const Strings = load("Strings.js",
  "LANGUAGES, STRINGS, MONTHS, languageFor, months, t, plural, timeUnits")
const Notes = load("Notes.js", "relativeTime, formatDate, formatShortDate")

test("every language carries every key", () => {
  const english = Object.keys(Strings.STRINGS.en).sort()
  for (const lang of Strings.LANGUAGES) {
    assert.deepEqual(Object.keys(Strings.STRINGS[lang]).sort(), english,
      `${lang} does not match the English key set`)
  }
})

test("no translation is left empty", () => {
  for (const lang of Strings.LANGUAGES)
    for (const [key, value] of Object.entries(Strings.STRINGS[lang]))
      assert.ok(typeof value === "string" && value.trim().length > 0, `${lang}.${key} is empty`)
})

test("every placeholder in English survives translation", () => {
  const placeholders = (text) => (text.match(/\{[a-z]+\}/g) || []).sort()
  for (const lang of Strings.LANGUAGES)
    for (const [key, value] of Object.entries(Strings.STRINGS.en))
      assert.deepEqual(placeholders(Strings.STRINGS[lang][key]), placeholders(value),
        `${lang}.${key} does not carry the same placeholders`)
})

test("every language has twelve months", () => {
  for (const lang of Strings.LANGUAGES)
    assert.equal(Strings.months(lang).length, 12)
  assert.equal(Strings.months("klingon").length, 12)  // falls back
})

test("languageFor honours an explicit choice over the session locale", () => {
  assert.equal(Strings.languageFor("es", "en_US.UTF-8"), "es")
  assert.equal(Strings.languageFor("en", "es_AR.UTF-8"), "en")
})

test("languageFor follows LANG when set to auto", () => {
  assert.equal(Strings.languageFor("auto", "es_AR.UTF-8"), "es")
  assert.equal(Strings.languageFor("auto", "es"), "es")
  assert.equal(Strings.languageFor("auto", "en_GB.UTF-8"), "en")
})

test("languageFor falls back to English for anything it does not speak", () => {
  assert.equal(Strings.languageFor("auto", "fr_FR.UTF-8"), "en")
  assert.equal(Strings.languageFor("auto", ""), "en")
  assert.equal(Strings.languageFor("auto", undefined), "en")
  assert.equal(Strings.languageFor("klingon", "fr_FR"), "en")
})

test("t fills placeholders", () => {
  assert.equal(Strings.t("en", "all.count.other", { n: 9 }), "9 notes")
  assert.equal(Strings.t("es", "all.count.other", { n: 9 }), "9 notas")
})

test("t falls back to English, then to the key itself", () => {
  assert.equal(Strings.t("fr", "all.clear"), "Clear")
  assert.equal(Strings.t("en", "no.such.key"), "no.such.key")
})

test("plural picks the form and passes the count through", () => {
  assert.equal(Strings.plural("en", "all.count", 1), "1 note")
  assert.equal(Strings.plural("en", "all.count", 4), "4 notes")
  assert.equal(Strings.plural("es", "all.count", 1), "1 nota")
  assert.equal(Strings.plural("es", "all.count", 4), "4 notas")
})

test("plural merges extra arguments with the count", () => {
  assert.equal(Strings.plural("en", "status.exported", 2, { path: "/tmp/x" }),
    "Exported 2 notes to /tmp/x")
})

test("relative time speaks the language it was handed", () => {
  const now = 1_000_000
  const es = Strings.timeUnits("es")
  assert.equal(Notes.relativeTime(now - 30, now, es), "ahora")
  assert.equal(Notes.relativeTime(now - 60 * 23, now, es), "23m")
  assert.equal(Notes.relativeTime(now - 86400 * 45, now, es), "1me")
  assert.equal(Notes.relativeTime(now - 86400 * 400, now, es), "1a")
})

test("relative time still works with no units at all", () => {
  const now = 1_000_000
  assert.equal(Notes.relativeTime(now - 30, now), "now")
  assert.equal(Notes.relativeTime(now - 86400 * 45, now), "1mo")
})

test("dates take their month names from the language", () => {
  const stamp = Math.floor(Date.UTC(2026, 7, 29, 12) / 1000)
  assert.match(Notes.formatDate(stamp, Strings.months("es")), /^\d+ ago 2026$/)
  assert.match(Notes.formatShortDate(stamp, Strings.months("en")), /^\d+ Aug$/)
})

// The table can be perfectly self-consistent and still be missing a key the
// UI asks for -- that shows up on screen as a raw key name like
// "menu.languageHeading", which is exactly how this test came to exist.
//
// Keys are matched as string literals rather than as `t("...")` calls: plenty
// of call sites pick their key with a ternary inside the parentheses, and a
// scan that only saw the first argument would call those keys unused.
const qmlKeys = () => {
  const namespaces = new Set(Object.keys(Strings.STRINGS.en).map((key) => key.split(".")[0]))
  const files = readdirSync(join(here, "..")).filter((f) => f.endsWith(".qml"))
  const literal = new Set()
  const plural = new Set()

  for (const file of files) {
    const source = readFileSync(join(here, "..", file), "utf8")
    for (const [, value] of source.matchAll(/"([^"\n]+)"/g))
      if (value.includes(".") && namespaces.has(value.split(".")[0])) literal.add(value)
    for (const [, key] of source.matchAll(/\.tn\("([^"]+)"/g)) plural.add(key)
  }
  return { literal, plural }
}

test("every key the QML asks for exists in the table", () => {
  const { literal, plural } = qmlKeys()
  const missing = []

  for (const key of literal)
    if (!(key in Strings.STRINGS.en) && !plural.has(key)) missing.push(key)
  for (const key of plural)
    for (const form of ["one", "other"])
      if (!(`${key}.${form}` in Strings.STRINGS.en)) missing.push(`${key}.${form}`)

  assert.deepEqual(missing.sort(), [], `used in QML, absent from the table:\n${missing.join("\n")}`)
})

test("no key in the table has been left behind by the UI", () => {
  const { literal, plural } = qmlKeys()
  const used = new Set(literal)
  for (const key of plural) {
    used.add(`${key}.one`)
    used.add(`${key}.other`)
  }
  // timeUnits() reads these itself rather than through a call site.
  for (const unit of ["now", "minutes", "hours", "days", "months", "years"])
    used.add(`time.${unit}`)

  const orphans = Object.keys(Strings.STRINGS.en).filter((key) => !used.has(key))
  assert.deepEqual(orphans, [], `translated but never shown:\n${orphans.join("\n")}`)
})
