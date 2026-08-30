// Exercises Notes.js in plain node. QML's `.pragma library` header is not
// valid JS, so the file is read, stripped and evaluated as a function body --
// the same source the shell loads, with no duplicate copy to drift.
import { readFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import { dirname, join } from "node:path"
import test from "node:test"
import assert from "node:assert/strict"

const here = dirname(fileURLToPath(import.meta.url))
const source = readFileSync(join(here, "..", "Notes.js"), "utf8").replace(/^\.pragma library\s*/, "")
const Notes = new Function(`${source}; return {
  palette, cycleColor, suggestColor, titleOf, previewOf, tagsOf, matches,
  filterNotes, activeNotes, byRecency, indexOfId, findById, relativeTime,
  formatDate, formatShortDate, deckSlice, orderDeck, autoDeckLimit,
  sortNotes, sortsFor, COLOR_ORDER, DECK_ORDERS, LIST_SORTS }`)()

const note = (over = {}) => ({
  id: "n1", title: "", body: "", color: "yellow", state: "active",
  created: 1000, updated: 1000, ...over,
})

test("cycleColor walks the palette and wraps", () => {
  let color = Notes.COLOR_ORDER[0]
  const seen = new Set()
  for (let i = 0; i < Notes.COLOR_ORDER.length; i++) {
    seen.add(color)
    color = Notes.cycleColor(color)
  }
  assert.equal(seen.size, Notes.COLOR_ORDER.length)
  assert.equal(color, Notes.COLOR_ORDER[0])
})

test("cycleColor tolerates an unknown colour", () => {
  assert.ok(Notes.COLOR_ORDER.includes(Notes.cycleColor("chartreuse")))
})

test("suggestColor picks the least used colour in the deck", () => {
  const notes = [note({ color: "yellow" }), note({ color: "yellow" }), note({ color: "blue" })]
  assert.equal(Notes.suggestColor(notes), "green")
})

test("suggestColor ignores archived notes", () => {
  const notes = Notes.COLOR_ORDER.map((color) => note({ color, state: "archived" }))
  assert.equal(Notes.suggestColor(notes), "yellow")
})

test("titleOf falls back to the first body line, then to a placeholder", () => {
  assert.equal(Notes.titleOf(note({ title: "Groceries" })), "Groceries")
  assert.equal(Notes.titleOf(note({ body: "- apple\n- banana" })), "- apple")
  assert.equal(Notes.titleOf(note()), "Untitled note")
})

test("previewOf collapses the body onto one line", () => {
  assert.equal(Notes.previewOf(note({ body: "- apple\n\n- 4x banana" })), "- apple - 4x banana")
})

test("tagsOf finds hash tags in title and body, deduplicated", () => {
  const tagged = note({ title: "Office #work", body: "ship it #work #api-v2" })
  assert.deepEqual(Notes.tagsOf(tagged), ["work", "api-v2"])
})

test("tagsOf ignores a hash inside a word", () => {
  assert.deepEqual(Notes.tagsOf(note({ body: "issue4#5" })), [])
})

test("matches requires every term, across title body and tags", () => {
  const n = note({ title: "Office", body: "understand all the apis #work" })
  assert.ok(Notes.matches(n, ""))
  assert.ok(Notes.matches(n, "office apis"))
  assert.ok(Notes.matches(n, "OFFICE"))
  assert.ok(Notes.matches(n, "#work"))
  assert.ok(!Notes.matches(n, "office groceries"))
  assert.ok(!Notes.matches(n, "#personal"))
})

test("filterNotes narrows by state and query together", () => {
  const notes = [
    note({ id: "a", title: "Office", state: "active" }),
    note({ id: "b", title: "Office archive", state: "archived" }),
    note({ id: "c", title: "Groceries", state: "active" }),
  ]
  assert.deepEqual(Notes.filterNotes(notes, "office", "all").map((n) => n.id), ["a", "b"])
  assert.deepEqual(Notes.filterNotes(notes, "office", "active").map((n) => n.id), ["a"])
  assert.deepEqual(Notes.filterNotes(notes, "", "archived").map((n) => n.id), ["b"])
})

test("byRecency sorts newest edit first without mutating the input", () => {
  const notes = [note({ id: "old", updated: 10 }), note({ id: "new", updated: 99 })]
  assert.deepEqual(Notes.byRecency(notes).map((n) => n.id), ["new", "old"])
  assert.deepEqual(notes.map((n) => n.id), ["old", "new"])
})

test("findById and indexOfId handle a missing note", () => {
  const notes = [note({ id: "a" })]
  assert.equal(Notes.findById(notes, "a").id, "a")
  assert.equal(Notes.findById(notes, "zz"), null)
  assert.equal(Notes.indexOfId(notes, "zz"), -1)
})

test("relativeTime uses the short forms the list column shows", () => {
  const now = 1_000_000
  assert.equal(Notes.relativeTime(now - 30, now), "now")
  assert.equal(Notes.relativeTime(now - 60 * 23, now), "23m")
  assert.equal(Notes.relativeTime(now - 3600 * 15, now), "15h")
  assert.equal(Notes.relativeTime(now - 86400 * 3, now), "3d")
  assert.equal(Notes.relativeTime(now - 86400 * 45, now), "1mo")
  assert.equal(Notes.relativeTime(now - 86400 * 400, now), "1y")
  assert.equal(Notes.relativeTime(now + 500, now), "now")
})

test("formatDate renders the footer and the short edited stamp", () => {
  const stamp = Math.floor(Date.UTC(2026, 7, 29, 12) / 1000)
  assert.match(Notes.formatDate(stamp), /^\d+ Aug 2026$/)
  assert.match(Notes.formatShortDate(stamp), /^\d+ Aug$/)
  assert.equal(Notes.formatDate(0), "")
})

test("deckSlice caps the fan and reports the overflow", () => {
  const notes = Array.from({ length: 11 }, (_, i) => note({ id: `n${i}` }))
  const slice = Notes.deckSlice(notes, 8, 0)
  assert.equal(slice.visible.length, 8)
  assert.equal(slice.overflow, 3)
  assert.equal(slice.total, 11)
  assert.equal(slice.visible[0].id, "n0")
})

test("deckSlice scrolls without running off the end", () => {
  const notes = Array.from({ length: 11 }, (_, i) => note({ id: `n${i}` }))
  assert.equal(Notes.deckSlice(notes, 8, 2).visible[0].id, "n2")
  assert.equal(Notes.deckSlice(notes, 8, 99).offset, 3)
  assert.equal(Notes.deckSlice(notes, 8, -5).offset, 0)
})

test("deckSlice leaves archived notes out of the deck", () => {
  const notes = [note({ id: "a" }), note({ id: "b", state: "archived" })]
  assert.deepEqual(Notes.deckSlice(notes, 8, 0).visible.map((n) => n.id), ["a"])
})

test("orderDeck defaults to most recently edited first", () => {
  const notes = [
    note({ id: "old", updated: 10, created: 1 }),
    note({ id: "new", updated: 99, created: 2 }),
    note({ id: "mid", updated: 50, created: 3 }),
  ]
  assert.deepEqual(Notes.orderDeck(notes).map((n) => n.id), ["new", "mid", "old"])
  assert.deepEqual(Notes.orderDeck(notes, "recent").map((n) => n.id), ["new", "mid", "old"])
})

test("orderDeck manual keeps the stored order, oldest reverses by creation", () => {
  const notes = [
    note({ id: "a", updated: 10, created: 30 }),
    note({ id: "b", updated: 99, created: 20 }),
    note({ id: "c", updated: 50, created: 10 }),
  ]
  assert.deepEqual(Notes.orderDeck(notes, "manual").map((n) => n.id), ["a", "b", "c"])
  assert.deepEqual(Notes.orderDeck(notes, "oldest").map((n) => n.id), ["c", "b", "a"])
})

test("orderDeck leaves archived notes out whatever the order", () => {
  const notes = [note({ id: "a" }), note({ id: "z", state: "archived", updated: 999 })]
  for (const order of Notes.DECK_ORDERS)
    assert.deepEqual(Notes.orderDeck(notes, order).map((n) => n.id), ["a"])
})

test("orderDeck does not mutate the notes it was handed", () => {
  const notes = [note({ id: "a", updated: 1 }), note({ id: "b", updated: 9 })]
  Notes.orderDeck(notes, "recent")
  Notes.orderDeck(notes, "oldest")
  assert.deepEqual(notes.map((n) => n.id), ["a", "b"])
})

test("deckSlice puts the newest edits on the edge under the default order", () => {
  const notes = Array.from({ length: 12 }, (_, i) => note({ id: `n${i}`, updated: i }))
  const slice = Notes.deckSlice(notes, 3, 0, "recent")
  assert.deepEqual(slice.visible.map((n) => n.id), ["n11", "n10", "n9"])
  assert.equal(slice.overflow, 9)
})

test("autoDeckLimit fits what the screen can hold", () => {
  assert.equal(Notes.autoDeckLimit(1140, 84, 4), 13)
  assert.equal(Notes.autoDeckLimit(600, 84, 4), 6)
  // Never zero: a deck of one tab is still a deck.
  assert.equal(Notes.autoDeckLimit(10, 84, 4), 1)
})

test("sortNotes orders by edit, creation, title and deck position", () => {
  const notes = [
    note({ id: "a", title: "Zebra", updated: 10, created: 30, position: 3 }),
    note({ id: "b", title: "apple", updated: 30, created: 10, position: 1 }),
    note({ id: "c", title: "Mango", updated: 20, created: 20, position: 2 }),
  ]
  assert.deepEqual(Notes.sortNotes(notes, "updated").map((n) => n.id), ["b", "c", "a"])
  assert.deepEqual(Notes.sortNotes(notes, "created").map((n) => n.id), ["a", "c", "b"])
  assert.deepEqual(Notes.sortNotes(notes, "deck").map((n) => n.id), ["b", "c", "a"])
  // Case-insensitive, or "apple" would sort after "Zebra".
  assert.deepEqual(Notes.sortNotes(notes, "title").map((n) => n.id), ["b", "c", "a"])
})

test("sortNotes falls back to most recently edited", () => {
  const notes = [note({ id: "old", updated: 1 }), note({ id: "new", updated: 9 })]
  assert.deepEqual(Notes.sortNotes(notes, "nonsense").map((n) => n.id), ["new", "old"])
  assert.deepEqual(Notes.sortNotes(notes).map((n) => n.id), ["new", "old"])
})

test("sortNotes sorts untitled notes by what their tab shows", () => {
  const notes = [
    note({ id: "a", title: "", body: "zebra crossing" }),
    note({ id: "b", title: "", body: "apple pie" }),
  ]
  assert.deepEqual(Notes.sortNotes(notes, "title").map((n) => n.id), ["b", "a"])
})

test("sortNotes leaves the array it was handed alone", () => {
  const notes = [note({ id: "a", updated: 1 }), note({ id: "b", updated: 9 })]
  Notes.sortNotes(notes, "title")
  assert.deepEqual(notes.map((n) => n.id), ["a", "b"])
})

test("sortsFor drops deck order on the archive tab", () => {
  assert.deepEqual(Notes.sortsFor("all"), Notes.LIST_SORTS)
  assert.deepEqual(Notes.sortsFor("active"), Notes.LIST_SORTS)
  assert.ok(!Notes.sortsFor("archived").includes("deck"))
})
