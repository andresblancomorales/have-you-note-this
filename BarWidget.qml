import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The deck's button in the bar. Reaching for the screen edge is the fast path
// and stays the fast path; this is the discoverable one -- something visible
// that says the notes are there, and how many are in the deck.
//
// Left click opens All Notes, right click writes a new note, middle click
// folds the deck open where it sits.
BarWidget {
  id: root
  moduleName: "ablanco.notethis"

  // The panel half of this same plugin, reached through the shell's loader
  // map. Talking to the live instance keeps the count a binding rather than a
  // poll, and keeps a click one function call instead of a subprocess.
  readonly property var plugin: {
    var shell = root.bar ? root.bar.shell : null
    if (!shell || !shell.panelLoaders) return null
    var loader = shell.panelLoaders[root.moduleName]
    return loader && loader.item ? loader.item : null
  }

  readonly property int noteCount: plugin ? plugin.deckNotes.length : 0
  readonly property bool allNotesOpen: plugin ? plugin.allNotesOpen === true : false

  readonly property string glyph: setting("glyph", "󰎞")
  readonly property bool showCount: setting("showCount", true) === true

  // A vertical bar has no room for a count beside the glyph.
  readonly property string label: (showCount && !vertical && noteCount > 0)
    ? (glyph + " " + noteCount) : glyph

  // The panel is loaded on demand by the shell; if it is not up yet, the IPC
  // path starts it the same way a keybind would.
  function callPlugin(method, arg) {
    if (plugin && typeof plugin[method] === "function") {
      plugin[method](arg)
      return
    }
    Quickshell.execDetached(["omarchy-shell", "notethis",
      method === "toggleAllNotes" ? "allNotes" : (method === "newNote" ? "newNote" : "toggle")])
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    hasVisualContent: text !== ""
    active: root.allNotesOpen
    horizontalMargin: 8.75
    verticalPadding: 8.75
    tooltipText: root.plugin ? root.plugin.tn("bar.tooltip", root.noteCount) : ""

    onPressed: function(pressedButton) {
      if (pressedButton === Qt.RightButton) root.callPlugin("newNote")
      else if (pressedButton === Qt.MiddleButton) root.callPlugin("toggleDeck")
      // Toggle, not open: a button that lights up when the window is open
      // should turn it off again, and one that does nothing on every click
      // after the first reads as broken.
      else root.callPlugin("toggleAllNotes")
    }
  }
}
