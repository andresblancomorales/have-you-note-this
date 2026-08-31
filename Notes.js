.pragma library

// Pure note logic -- palette, search, previews, dates. Kept out of QML so the
// deck and the All Notes window agree on what a note looks like, and so the
// rules can be exercised by `tests/test-notes.mjs` without a compositor.

// One colour per note, in the order `cycleColor` walks. `paper` is the card,
// `ink` the writing on it; both are fixed rather than theme-derived, because a
// sticky note that restyles itself with the desktop theme stops being a
// recognisable object on the screen edge.
var PALETTE = {
  yellow: { paper: "#FBDC6E", ink: "#4A3B0E", rule: "#C9A82C" },
  blue:   { paper: "#A9CDFA", ink: "#16324F", rule: "#6E9DD6" },
  green:  { paper: "#A9E9C6", ink: "#12402C", rule: "#6BBE96" },
  purple: { paper: "#D9C9F7", ink: "#34215C", rule: "#A48ED6" },
  pink:   { paper: "#F7B8CE", ink: "#55182F", rule: "#D0849F" },
  orange: { paper: "#F5A583", ink: "#57230C", rule: "#D0784F" }
}

var COLOR_ORDER = ["yellow", "blue", "green", "purple", "pink", "orange"]

function palette(color) {
  return PALETTE[color] || PALETTE.yellow
}

function cycleColor(color) {
  var index = COLOR_ORDER.indexOf(color)
  return COLOR_ORDER[(index + 1) % COLOR_ORDER.length]
}

// A new note takes the colour least represented in the deck, so a deck built
// one note at a time comes out varied instead of six yellows.
function suggestColor(notes) {
  var counts = {}
  for (var c = 0; c < COLOR_ORDER.length; c++) counts[COLOR_ORDER[c]] = 0
  for (var n = 0; n < notes.length; n++)
    if (notes[n].state === "active" && counts[notes[n].color] !== undefined)
      counts[notes[n].color] += 1
  var best = COLOR_ORDER[0]
  for (var i = 1; i < COLOR_ORDER.length; i++)
    if (counts[COLOR_ORDER[i]] < counts[best]) best = COLOR_ORDER[i]
  return best
}

function titleOf(note) {
  if (!note) return ""
  var title = (note.title || "").trim()
  if (title.length > 0) return title
  // An untitled note still needs a tab label, and its first line is the
  // closest thing it has to a name.
  var firstLine = (note.body || "").split("\n")[0].trim()
  return firstLine.length > 0 ? firstLine : "Untitled note"
}

function previewOf(note) {
  var body = (note && note.body ? note.body : "").replace(/\s+/g, " ").trim()
  return body
}

// Checklists. A sticky note is a list most of the time, so `- [ ]` and `- [x]`
// are understood in the body -- stored as the markdown they are, so an export
// is still a checklist wherever it lands.
var CHECK_ITEM = /^(\s*[-*]\s\[)([ xX])(\]\s?)/

function checklist(note) {
  var lines = ((note && note.body) || "").split("\n")
  var total = 0, done = 0
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(CHECK_ITEM)
    if (!match) continue
    total += 1
    if (match[2] !== " ") done += 1
  }
  return { total: total, done: done }
}

// Bounds of the line containing `position`, so a click or a caret can be
// resolved to the item it is sitting in.
function lineRangeAt(body, position) {
  var text = body || ""
  var at = Math.max(0, Math.min(position || 0, text.length))
  var start = text.lastIndexOf("\n", at - 1) + 1
  var end = text.indexOf("\n", at)
  return { start: start, end: end === -1 ? text.length : end }
}

// Flip the box on the line under `position`. Returns null when that line is
// not a checklist item, so callers can leave the click alone.
//
// `markerOnly` is what a click passes: only a hit inside the "- [ ]" itself
// counts, or typing in the text would tick things by accident. The keyboard
// path passes false, because the caret is already a deliberate choice of line.
function toggleChecklistAt(body, position, markerOnly) {
  var text = body || ""
  var range = lineRangeAt(text, position)
  var line = text.substring(range.start, range.end)
  var match = line.match(CHECK_ITEM)
  if (!match) return null
  if (markerOnly && (position - range.start) > match[0].length) return null
  var flipped = match[1] + (match[2] === " " ? "x" : " ") + match[3]
  return text.substring(0, range.start) + flipped + line.substring(match[0].length)
    + text.substring(range.end)
}

function tagsOf(note) {
  var found = []
  var source = ((note && note.body) || "") + " " + ((note && note.title) || "")
  var matches = source.match(/(^|\s)#([\w-]+)/g) || []
  for (var i = 0; i < matches.length; i++) {
    var tag = matches[i].trim().substring(1).toLowerCase()
    if (found.indexOf(tag) === -1) found.push(tag)
  }
  return found
}

// Search runs over titles, bodies and tags, all terms required, so "office
// api" finds the note that mentions both wherever they sit.
function matches(note, query) {
  var trimmed = (query || "").trim().toLowerCase()
  if (trimmed.length === 0) return true
  var haystack = [(note.title || ""), (note.body || ""), tagsOf(note).join(" ")]
    .join(" ").toLowerCase()
  var terms = trimmed.split(/\s+/)
  for (var i = 0; i < terms.length; i++) {
    var term = terms[i]
    if (term.charAt(0) === "#") {
      if (tagsOf(note).indexOf(term.substring(1)) === -1) return false
    } else if (haystack.indexOf(term) === -1) {
      return false
    }
  }
  return true
}

function filterNotes(notes, query, state) {
  var out = []
  for (var i = 0; i < notes.length; i++) {
    var note = notes[i]
    if (state && state !== "all" && note.state !== state) continue
    if (!matches(note, query)) continue
    out.push(note)
  }
  return out
}

function activeNotes(notes) {
  return filterNotes(notes, "", "active")
}

// A pinned note is stuck to the desktop, so it leaves the deck -- being in
// both places at once would just be the same note twice.
function isPinned(note) {
  return !!(note && note.pinned)
}

function deckCandidates(notes) {
  var out = []
  for (var i = 0; i < notes.length; i++)
    if (notes[i].state === "active" && !isPinned(notes[i])) out.push(notes[i])
  return out
}

function pinnedNotes(notes) {
  var out = []
  for (var i = 0; i < notes.length; i++)
    if (isPinned(notes[i]) && notes[i].state !== "archived") out.push(notes[i])
  return out
}

// How the All Notes list is ordered. Separate from the deck's own order: the
// deck answers "what am I working on", the list answers "where is that note",
// and the two questions do not want the same answer.
var LIST_SORTS = ["updated", "created", "title", "deck"]

// Deck order means nothing for archived notes -- they are not in the deck --
// so the archive tab is offered one option fewer.
function sortsFor(filter) {
  return filter === "archived" ? ["updated", "created", "title"] : LIST_SORTS
}

function sortNotes(notes, sort) {
  var out = notes.slice()
  if (sort === "created")
    return out.sort(function(a, b) { return (b.created || 0) - (a.created || 0) })
  if (sort === "title")
    return out.sort(function(a, b) {
      return titleOf(a).toLowerCase().localeCompare(titleOf(b).toLowerCase())
    })
  if (sort === "deck")
    return out.sort(function(a, b) { return (a.position || 0) - (b.position || 0) })
  return out.sort(function(a, b) { return (b.updated || 0) - (a.updated || 0) })
}

function byRecency(notes) {
  return notes.slice().sort(function(a, b) { return (b.updated || 0) - (a.updated || 0) })
}

function indexOfId(notes, id) {
  for (var i = 0; i < notes.length; i++) if (notes[i].id === id) return i
  return -1
}

function findById(notes, id) {
  var index = indexOfId(notes, id)
  return index === -1 ? null : notes[index]
}

// "23m", "15h", "3d" -- the same short forms the list column uses, so a row
// stays one line whatever the age of the note.
var DEFAULT_UNITS = { now: "now", minutes: "{n}m", hours: "{n}h",
                      days: "{n}d", months: "{n}mo", years: "{n}y" }

function relativeTime(epochSeconds, nowSeconds, units) {
  var unit = units || DEFAULT_UNITS
  var now = nowSeconds === undefined ? Math.floor(Date.now() / 1000) : nowSeconds
  var delta = Math.max(0, now - (epochSeconds || 0))
  function form(key, value) { return String(unit[key]).split("{n}").join(String(value)) }
  if (delta < 60) return unit.now
  if (delta < 3600) return form("minutes", Math.floor(delta / 60))
  if (delta < 86400) return form("hours", Math.floor(delta / 3600))
  if (delta < 86400 * 30) return form("days", Math.floor(delta / 86400))
  if (delta < 86400 * 365) return form("months", Math.floor(delta / (86400 * 30)))
  return form("years", Math.floor(delta / (86400 * 365)))
}

var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
              "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

// Month names come from the caller so this stays language-free; Strings.js
// holds the lists.
function formatDate(epochSeconds, months) {
  if (!epochSeconds) return ""
  var names = months || MONTHS
  var date = new Date(epochSeconds * 1000)
  return date.getDate() + " " + names[date.getMonth()] + " " + date.getFullYear()
}

function formatShortDate(epochSeconds, months) {
  if (!epochSeconds) return ""
  var names = months || MONTHS
  var date = new Date(epochSeconds * 1000)
  return date.getDate() + " " + names[date.getMonth()]
}

// What the deck puts on the edge first, when it cannot hold everything.
//
//   recent  most recently edited first -- the default, because the deck is
//           the working set: the note you just touched is the one you reach
//           for next, and a note you write should not fall off the edge the
//           moment a ninth note exists
//   manual  the order the notes were put in, which is what dragging a note
//           up the deck would rearrange
//   oldest  first written first, for a deck used as a queue
function orderDeck(notes, order) {
  var active = deckCandidates(notes)
  if (order === "manual") return active
  if (order === "oldest")
    return active.slice().sort(function(a, b) { return (a.created || 0) - (b.created || 0) })
  return byRecency(active)
}

var DECK_ORDERS = ["recent", "manual", "oldest"]

// How many tabs fit on a screen of this height before they get too short to
// carry a readable label. `deckLimit: 0` in settings means "as many as fit",
// which is the honest answer to a deck with thirty notes in it: a fixed eight
// wastes two thirds of a tall screen and overflows a short one.
function autoDeckLimit(availableHeight, minTabHeight, gap) {
  var min = minTabHeight || 84
  var spacing = gap === undefined ? 4 : gap
  return Math.max(1, Math.floor((availableHeight + spacing) / (min + spacing)))
}

// The deck shows a fixed number of tabs and hides the rest behind a "+N more"
// tile; `visible` is what fans out, `overflow` is what the tile scrolls to.
function deckSlice(notes, limit, offset, order) {
  var active = orderDeck(notes, order)
  var start = Math.max(0, Math.min(offset || 0, Math.max(0, active.length - limit)))
  return {
    visible: active.slice(start, start + limit),
    overflow: Math.max(0, active.length - limit),
    offset: start,
    total: active.length
  }
}
