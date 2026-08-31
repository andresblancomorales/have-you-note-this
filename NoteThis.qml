import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Notes.js" as Notes
import "Strings.js" as Strings

// Have you note-this? -- a deck of sticky notes docked to the right edge of every
// screen. This is the plugin root: it owns the store, the shared open/hover
// state, and one DeckWindow per screen. The windows are thin; anything two
// screens or two surfaces must agree on lives here.
Item {
  id: root

  // Injected by the shell host when the plugin loads.
  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  readonly property string pluginDir: {
    var dir = Qt.resolvedUrl(".").toString()
    return dir.indexOf("file://") === 0 ? dir.substring(7) : dir
  }

  // ------------------------------------------------------- shared state

  // The note currently lifted out of the deck, and the screen it opened on.
  // One note is open at a time across every screen, matching the single deck
  // the user is reaching for.
  property string openNoteId: ""
  property string openScreen: ""

  // The screen whose deck is fanned. Set by whichever DeckWindow the pointer
  // entered; cleared when it leaves.
  property string hoveredScreen: ""
  // The deck held open regardless of the pointer -- while a note is open,
  // while a menu is up, and by the toggle shortcut. Named for what it does to
  // the deck: `note.pinned` is a different thing entirely, a note kept above
  // the windows, and the two read alike in a hurry.
  property bool deckHeld: false

  // True when the deck was opened from the keyboard rather than reached for.
  // Only then does the deck take the keyboard: a deck that grabbed it every
  // time the pointer brushed the screen edge would be unusable.
  property bool keyboardDeck: false

  readonly property bool anyOpen: openNoteId !== ""

  // A note coming back from the top of the screen says so from the resting
  // pill -- its dash nudges out a few times and settles. Nothing opens: the
  // deck fans out when the pointer reaches for it, and a note returning is
  // not the pointer asking for anything.
  property string peekNoteId: ""
  property string peekScreen: ""

  Timer {
    id: peekTimer
    // Long enough to read the name of the note that came back.
    interval: 2000
    onTriggered: {
      root.peekNoteId = ""
      root.peekScreen = ""
    }
  }

  // A deleted note is held here for ten seconds so the toast can put them
  // back. A list, not one note: All Notes deletes whole selections.
  property var pendingDeletes: []

  readonly property var deckNotes: Notes.deckCandidates(noteStore.notes)
  // The pinned windows are keyed by id, not by note object.
  //
  // A note object is replaced on every write -- the optimistic patch and then
  // the daemon's reply, so twice per keystroke's save -- and an Instantiator
  // whose model held those objects tore its window down and built a new one
  // each time. Typing in a pinned note made it blink and drop the caret. Ids
  // are strings, so the model only changes when a note is actually pinned or
  // unpinned, and the window looks the note up itself.
  property var pinnedIds: []

  function refreshPinnedIds() {
    var pinned = Notes.pinnedNotes(noteStore.notes)
    var next = []
    for (var i = 0; i < pinned.length; i++) next.push(pinned[i].id)
    if (next.length === root.pinnedIds.length) {
      var same = true
      for (var j = 0; j < next.length; j++) {
        if (next[j] !== root.pinnedIds[j]) { same = false; break }
      }
      if (same) return
    }
    root.pinnedIds = next
  }

  Connections {
    target: noteStore
    function onNotesChanged() { root.refreshPinnedIds() }
  }

  // Read by the bar widget, so its button carries the window's open state --
  // and by the toggle below, so summoning twice puts the window away.
  readonly property bool allNotesOpen: allNotesLoader.item ? allNotesLoader.item.visible : false

  // ---------------------------------------------------------- settings

  property bool overFullscreen: false
  // 0 means "as many tabs as the screen can hold"; a number pins it.
  property int deckLimit: 0
  // "auto" follows the session's LANG. Omarchy has no language setting of its
  // own -- no qsTr, no .qm files anywhere in the shell -- so there is nothing
  // above this to inherit from, and a machine whose locale is one language and
  // whose owner is another needs the override.
  property string languageSetting: "auto"

  readonly property string language: Strings.languageFor(languageSetting, Quickshell.env("LANG"))
  readonly property var months: Strings.months(language)
  readonly property var timeUnits: Strings.timeUnits(language)

  function t(key, args) { return Strings.t(root.language, key, args) }
  function tn(key, count, args) { return Strings.plural(root.language, key, count, args) }
  function since(epoch) { return Notes.relativeTime(epoch, undefined, root.timeUnits) }
  function shortDate(epoch) { return Notes.formatShortDate(epoch, root.months) }
  function longDate(epoch) { return Notes.formatDate(epoch, root.months) }

  // How the deck decides which notes make it onto the edge. See Notes.js.
  property string deckOrder: "recent"

  // The All Notes list sorts per tab: "where is that note" has a different
  // answer when you are looking at the archive than when you are looking at
  // what is on the deck right now.
  property var listSort: ({ all: "updated", active: "updated", archived: "updated" })

  readonly property string settingsDir:
    (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/notethis"

  FileView {
    id: settingsFile
    path: root.settingsDir + "/settings.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.applySettings(text())
    onFileChanged: { reload(); root.applySettings(text()) }
  }

  // FileView writes a file, it does not make the folder around it -- so every
  // setting the user changed was being written into a directory that did not
  // exist, and silently lost. Made once at startup, long before a click can
  // reach a menu.
  Process {
    id: settingsDirMaker
    command: ["mkdir", "-p", root.settingsDir]
    running: true
  }

  function applySettings(raw) {
    try {
      var parsed = JSON.parse(raw || "{}")
      if (typeof parsed.overFullscreen === "boolean") root.overFullscreen = parsed.overFullscreen
      if (typeof parsed.deckLimit === "number")
        root.deckLimit = Math.max(0, Math.min(24, Math.round(parsed.deckLimit)))
      if (Notes.DECK_ORDERS.indexOf(parsed.deckOrder) !== -1)
        root.deckOrder = parsed.deckOrder
      if (Strings.LANGUAGES.indexOf(parsed.language) !== -1 || parsed.language === "auto")
        root.languageSetting = parsed.language
      if (parsed.listSort && typeof parsed.listSort === "object") {
        var next = { all: "updated", active: "updated", archived: "updated" }
        for (var tab in next)
          if (Notes.sortsFor(tab).indexOf(parsed.listSort[tab]) !== -1)
            next[tab] = parsed.listSort[tab]
        root.listSort = next
      }
    } catch (error) {
      console.warn("notethis: unreadable settings.json, using defaults")
    }
  }

  function saveSettings() {
    settingsFile.setText(JSON.stringify({
      overFullscreen: root.overFullscreen,
      deckLimit: root.deckLimit,
      deckOrder: root.deckOrder,
      listSort: root.listSort,
      language: root.languageSetting
    }, null, 2) + "\n")
  }

  // ------------------------------------------------------------- store

  Store {
    id: noteStore
    helper: root.pluginDir + "bin/notethis-store"
  }

  // ----------------------------------------------------------- actions

  function screenNameFor(fallback) {
    var monitor = Hyprland.focusedMonitor
    if (monitor && monitor.name) return monitor.name
    return fallback || (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")
  }

  function newNote() {
    root.deckHeld = true
    // The new note takes the keyboard itself; the deck behind it should not
    // grab it back when the note closes.
    root.keyboardDeck = false
    root.openScreen = screenNameFor(root.openScreen)
    noteStore.create({}, function(note, error) {
      if (note) root.openNoteId = note.id
    })
  }

  function openNote(id, screenName, fromKeyboard) {
    root.openScreen = screenName || screenNameFor(root.openScreen)
    root.openNoteId = id
    root.deckHeld = true
    if (fromKeyboard !== true && !root.keyboardDeck) root.keyboardDeck = false
  }

  // Closing a note that was opened from the deck's keyboard cursor goes back
  // to the deck, not all the way out: Esc walks back one step at a time.
  function closeNote() {
    root.openNoteId = ""
    if (!root.keyboardDeck) root.deckHeld = false
  }

  function closeDeck() {
    root.openNoteId = ""
    root.deckHeld = false
    root.keyboardDeck = false
    // A deck folded by the shortcut must not stay fanned on the strength of a
    // hover flag the pointer set on its way past.
    root.hoveredScreen = ""
  }

  function toggleDeck() {
    if (root.deckHeld) {
      root.closeDeck()
    } else {
      root.deckHeld = true
      root.keyboardDeck = true
      root.openScreen = screenNameFor(root.openScreen)
      root.hoveredScreen = root.openScreen
    }
  }

  function setLanguage(value) {
    if (value !== "auto" && Strings.LANGUAGES.indexOf(value) === -1) return
    root.languageSetting = value
    root.saveSettings()
  }

  function setDeckOrder(order) {
    if (Notes.DECK_ORDERS.indexOf(order) === -1) return
    root.deckOrder = order
    root.saveSettings()
  }

  // Every action takes a list. The single-note callers -- the open note's own
  // buttons, the deck's context menu -- hand over a list of one, so there is
  // one implementation of each action rather than two that can disagree.
  function sortFor(filter) {
    var sort = root.listSort[filter]
    return Notes.sortsFor(filter).indexOf(sort) === -1 ? "updated" : sort
  }

  function setListSort(filter, sort) {
    if (Notes.sortsFor(filter).indexOf(sort) === -1) return
    var next = {}
    for (var tab in root.listSort) next[tab] = root.listSort[tab]
    next[filter] = sort
    root.listSort = next
    root.saveSettings()
  }

  function archiveNotes(ids) {
    for (var i = 0; i < (ids || []).length; i++) {
      noteStore.setState(ids[i], "archived")
      if (root.openNoteId === ids[i]) root.closeNote()
    }
  }

  function unarchiveNotes(ids) {
    for (var i = 0; i < (ids || []).length; i++) noteStore.setState(ids[i], "active")
  }

  // Peel a note off the deck and stick it to the desktop. It lands where the
  // pointer's screen is, near the top left, and the user drags it from there.
  function pinNote(id) {
    var note = noteStore.note(id)
    if (!note) return
    noteStore.update(id, {
      pinned: true,
      pinScreen: screenNameFor(root.openScreen),
      pinX: note.pinX > 0 ? note.pinX : 80,
      pinY: note.pinY > 0 ? note.pinY : 80,
      touch: false
    })
    // The note just left the deck for the top of the screen; leaving the deck
    // fanned open behind it is state nobody asked to keep.
    root.closeDeck()
  }

  function unpinNote(id) {
    var note = noteStore.note(id)
    noteStore.update(id, { pinned: false, touch: false })
    // Back among a dozen dashes, a note is easy to lose track of.
    root.peekScreen = (note && note.pinScreen) ? note.pinScreen : screenNameFor(root.openScreen)
    root.peekNoteId = id
    peekTimer.restart()
  }

  function pinNotes(ids) {
    for (var i = 0; i < (ids || []).length; i++) pinNote(ids[i])
  }

  function unpinNotes(ids) {
    for (var i = 0; i < (ids || []).length; i++) unpinNote(ids[i])
  }

  function togglePin(id) {
    var note = noteStore.note(id)
    if (!note) return
    if (note.pinned) unpinNote(id)
    else pinNote(id)
  }

  function archiveNote(id) { archiveNotes([id]) }
  function unarchiveNote(id) { unarchiveNotes([id]) }

  // Delete keeps the notes in hand for ten seconds. The toast lives in the
  // deck window; this owns the timer so the window can come and go under it.
  function deleteNotes(ids) {
    var held = []
    for (var i = 0; i < (ids || []).length; i++) {
      var note = noteStore.note(ids[i])
      if (!note) continue
      held.push(note)
      if (root.openNoteId === ids[i]) root.closeNote()
      noteStore.remove(ids[i])
    }
    if (held.length === 0) return
    // A delete started from the All Notes window has no screen of its own, so
    // the toast is put where the user is looking.
    root.openScreen = screenNameFor(root.openScreen)
    root.pendingDeletes = held
    undoTimer.restart()
  }

  function deleteNote(id) { deleteNotes([id]) }

  function undoDelete() {
    var held = root.pendingDeletes
    if (held.length === 0) return
    root.pendingDeletes = []
    undoTimer.stop()
    for (var i = 0; i < held.length; i++) noteStore.restore(held[i])
  }

  Timer {
    id: undoTimer
    interval: 10000
    onTriggered: root.pendingDeletes = []
  }

  // --------------------------------------------------------- all notes

  // The cheat sheet lives in the All Notes window; reaching it from the pill
  // means opening that window on the way.
  function showAbout() {
    showAllNotes("all")
    if (allNotesLoader.item) allNotesLoader.item.openAbout()
    else allNotesLoader.pendingAbout = true
  }

  function showShortcuts() {
    showAllNotes("all")
    if (allNotesLoader.item) allNotesLoader.item.openShortcuts()
    else allNotesLoader.pendingShortcuts = true
  }

  function hideAllNotes() {
    if (allNotesLoader.item) allNotesLoader.item.hide()
  }

  // Summoning something already summoned should put it away. Quickshell's
  // windows ignore the compositor's close request -- Super+W does nothing to
  // them, and the `closed` signal never fires -- so this and Esc are the ways
  // out. A button that does nothing on every press after the first reads as
  // broken, which is exactly how it was reported.
  function toggleAllNotes() {
    if (root.allNotesOpen) hideAllNotes()
    else showAllNotes("all")
  }

  function showAllNotes(filter) {
    allNotesLoader.pendingFilter = filter || "all"
    if (allNotesLoader.item) allNotesLoader.item.show(allNotesLoader.pendingFilter)
    else allNotesLoader.active = true
  }

  // The window is built the first time it is asked for and then kept, so
  // reopening it is instant and its search state survives a close.
  Loader {
    id: allNotesLoader
    property string pendingFilter: "all"
    property bool pendingShortcuts: false
    property bool pendingAbout: false
    active: false
    source: "AllNotes.qml"
    onLoaded: {
      item.host = root
      item.store = noteStore
      item.show(allNotesLoader.pendingFilter)
      if (allNotesLoader.pendingShortcuts) {
        allNotesLoader.pendingShortcuts = false
        item.openShortcuts()
      }
      if (allNotesLoader.pendingAbout) {
        allNotesLoader.pendingAbout = false
        item.openAbout()
      }
    }
  }

  // ------------------------------------------------------- host surface

  // `summon`/`toggle` from the shell. The payload picks a view so a keybind
  // can go straight to the archive.
  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") } catch (error) {}
    if (payload.view === "all") showAllNotes("all")
    else if (payload.view === "archive") showAllNotes("archived")
    else if (payload.view === "new") newNote()
    else toggleDeck()
  }

  function close() {
    closeNote()
    if (allNotesLoader.item) allNotesLoader.item.hide()
  }

  IpcHandler {
    target: "notethis"

    function newNote(): string { root.newNote(); return "ok" }
    function allNotes(): string { root.toggleAllNotes(); return "ok" }
    function archive(): string { root.showAllNotes("archived"); return "ok" }
    function shortcuts(): string { root.showShortcuts(); return "ok" }
    function about(): string { root.showAbout(); return "ok" }
    function toggle(): string { root.toggleDeck(); return "ok" }
    function count(): string { return String(root.deckNotes.length) }
    function pin(id: string): string { root.togglePin(id); return "ok" }
    // id, title and state for every note, so a script can pick one to open.
    function list(): string {
      var out = []
      for (var i = 0; i < noteStore.notes.length; i++) {
        var note = noteStore.notes[i]
        out.push({ id: note.id, title: Notes.titleOf(note), color: note.color, state: note.state })
      }
      return JSON.stringify(out)
    }
    // Lift one note out of the deck by id, on the screen with focus.
    function openNote(id: string): string {
      if (!noteStore.note(id)) return "unknown"
      root.openNote(id, root.screenNameFor(""))
      return "ok"
    }
    // Re-read the database. Anything that writes to it from outside the
    // shell (an import, a restore from backup) uses this to show up.
    function reload(): string { noteStore.refresh(); return "ok" }
    function ping(): string { return noteStore.ready ? "ok" : "starting" }
    // What the deck thinks it is doing, for troubleshooting a deck that will
    // not fan out on the screen the pointer is actually on.
    function state(): string {
      var names = []
      for (var i = 0; i < Quickshell.screens.length; i++) names.push(Quickshell.screens[i].name)
      return JSON.stringify({
        deckHeld: root.deckHeld,
        peekScreen: root.peekScreen,
        openScreen: root.openScreen,
        hoveredScreen: root.hoveredScreen,
        openNoteId: root.openNoteId,
        notes: noteStore.notes.length,
        deckNotes: root.deckNotes.length,
        screens: names,
        focusedMonitor: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : null
      })
    }
  }

  // ------------------------------------------------------------ windows

  // One window per pinned note, on the screen it was dropped on. A note whose
  // screen is gone comes back on the first one, rather than nowhere.
  Instantiator {
    model: root.pinnedIds

    delegate: PinnedNote {
      required property string modelData
      host: root
      store: noteStore
      noteId: modelData
    }
  }

  Variants {
    model: Quickshell.screens

    DeckWindow {
      required property var modelData
      screen: modelData
      host: root
      store: noteStore
    }
  }
}
