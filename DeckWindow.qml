import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Notes.js" as Notes
import "Strings.js" as Strings

// One screen's deck. Three states, one movement:
//
//   at rest   a thin pill on the edge, one coloured dash per note
//   reached   the notes shingle down the edge, 45ms apart, showing their tabs
//   opened    one note slides clear of the deck, at full size, ready to type
//
// The layer-shell surface is a fixed full-height strip; what changes is the
// input mask, so the desktop under the transparent parts stays clickable.
PanelWindow {
  id: win

  property var host: null
  property var store: null

  readonly property string screenName: screen ? screen.name : ""
  readonly property bool isOpenScreen: host && host.openScreen === screenName
  readonly property var openNote: (isOpenScreen && host && host.openNoteId !== "")
    ? store.note(host.openNoteId) : null

  // Fanned while the pointer is over this deck, or while this screen holds
  // the open note. `pinned` survives the pointer wandering off the tabs.
  readonly property bool fanned: (host && host.hoveredScreen === screenName)
    || (host && host.pinned && isOpenScreen)

  // Once the user has clicked into the open note, walking the pointer away
  // must not yank it shut mid-sentence.
  property bool editorEngaged: false

  property int deckOffset: 0

  // Where the keyboard is in the deck, counted over every active note rather
  // than over the tabs on screen, so moving past the last visible tab scrolls
  // the deck instead of stopping at it.
  property int cursorIndex: -1

  readonly property var orderedNotes: (host && store)
    ? Notes.orderDeck(store.notes, host.deckOrder) : []

  // The deck answers the keyboard only when it was opened from the keyboard,
  // and only until a note takes over.
  readonly property bool keyboardDriving: host !== null && host.keyboardDeck
    && isOpenScreen && openNote === null && fanned

  // `deckLimit: 0` lets the deck hold as many tabs as this screen fits, which
  // is what a deck with thirty notes in it actually needs -- a fixed eight
  // leaves two thirds of a tall screen empty and still overflows a short one.
  readonly property int effectiveLimit: {
    if (!host) return 1
    if (host.deckLimit > 0) return host.deckLimit
    return Notes.autoDeckLimit(height - 140, 84, 4)
  }

  readonly property var slice: (host && store)
    ? Notes.deckSlice(store.notes, effectiveLimit, deckOffset, host.deckOrder)
    : ({ visible: [], overflow: 0, offset: 0, total: 0 })

  // ------------------------------------------------------------- metrics

  readonly property int tabWidth: 46
  // A full deck has to fit the screen it is on: eight tabs at their natural
  // height overflow a laptop panel, so they shrink to share what is there,
  // down to a floor where the label is still readable.
  readonly property int tabHeight: {
    var count = Math.max(1, slice.visible.length)
    var available = height - 140
    return Math.max(56, Math.min(128, Math.floor((available - (count - 1) * 4) / count)))
  }
  readonly property int dashWidth: 7
  readonly property int dashHeight: 26
  readonly property int editorWidth: 400
  readonly property int editorHeight: 320
  readonly property int reachWidth: 16

  anchors { top: true; right: true; bottom: true }
  implicitWidth: editorWidth + tabWidth + 40
  color: "transparent"

  WlrLayershell.namespace: "notethis"
  WlrLayershell.layer: (host && host.overFullscreen) ? WlrLayer.Overlay : WlrLayer.Top
  // The deck only wants the keyboard while a note is open; the rest of the
  // time it must not steal focus from whatever is being typed into.
  //
  // Exclusive rather than OnDemand: OnDemand hands focus over on a click, so
  // a note opened from Super + Alt + N had no caret and swallowed everything
  // typed into it. The same contract as the shell's other input surfaces --
  // the clipboard and emoji overlays both take the keyboard outright. Esc
  // gives it back.
  WlrLayershell.keyboardFocus: (win.openNote || win.keyboardDriving)
    ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore

  // Everything the deck can be clicked on, and nothing else. Items collapse
  // to zero size when their state is off, so an idle deck only holds the
  // 16px reach strip.
  mask: Region {
    Region { item: reachStrip }
    Region { item: deckSurface }
    Region { item: plusButton }
    Region { item: editorHolder }
    Region { item: toast }
    Region { item: menuPopup }
  }

  // -------------------------------------------------------------- state

  function fanOpen() {
    if (host) host.hoveredScreen = win.screenName
  }

  function fanClosed() {
    if (!host) return
    if (host.hoveredScreen === win.screenName) host.hoveredScreen = ""
    // A note the user never engaged with rides the fan closed with it.
    if (win.openNote && !win.editorEngaged && !menuPopup.open) host.closeNote()
  }

  Timer {
    id: leaveTimer
    interval: 220
    onTriggered: if (!deckHover.hovered && !editorHover.hovered && !menuPopup.open) win.fanClosed()
  }

  // ---------------------------------------------------------- keyboard

  function moveCursor(delta) {
    var total = orderedNotes.length
    if (total === 0) return
    var next = cursorIndex < 0 ? (delta > 0 ? 0 : total - 1) : cursorIndex + delta
    cursorIndex = Math.max(0, Math.min(total - 1, next))
    // Follow the cursor with the deck rather than letting it walk off the end
    // of what is on screen.
    if (cursorIndex < deckOffset) deckOffset = cursorIndex
    else if (cursorIndex >= deckOffset + effectiveLimit)
      deckOffset = cursorIndex - effectiveLimit + 1
  }

  function openCursor() {
    if (cursorIndex < 0 || cursorIndex >= orderedNotes.length) return
    win.editorEngaged = false
    host.openNote(orderedNotes[cursorIndex].id, win.screenName, true)
  }

  onKeyboardDrivingChanged: {
    if (!keyboardDriving) return
    if (cursorIndex < 0 || cursorIndex >= orderedNotes.length) cursorIndex = 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  // Focus has to live on an item for Keys to fire; the layer surface only
  // decides whether the keyboard reaches this window at all.
  FocusScope {
    id: keyCatcher
    anchors.fill: parent
    focus: win.keyboardDriving

    Keys.onPressed: function(event) {
      if (!win.keyboardDriving) return
      if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
        win.moveCursor(1); event.accepted = true
      } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
        win.moveCursor(-1); event.accepted = true
      } else if (event.key === Qt.Key_Home) {
        win.cursorIndex = 0; win.deckOffset = 0; event.accepted = true
      } else if (event.key === Qt.Key_End) {
        win.cursorIndex = win.orderedNotes.length - 1
        win.deckOffset = Math.max(0, win.orderedNotes.length - win.effectiveLimit)
        event.accepted = true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        win.openCursor(); event.accepted = true
      } else if (event.key === Qt.Key_Escape) {
        win.host.closeDeck(); event.accepted = true
      } else if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) {
        win.host.newNote(); event.accepted = true
      }
    }
  }

  function noteTapped(id) {
    if (host.openNoteId === id) {
      host.closeNote()
    } else {
      win.editorEngaged = false
      host.openNote(id, win.screenName)
    }
  }

  // Which note the caret was last put in. `openNote` is a binding over the
  // store, so it hands back a fresh object on every keystroke's write-back --
  // focusing on each of those would yank the caret out of the field being
  // typed in. Only a genuinely different note earns a focus call.
  property string focusedNoteId: ""

  onOpenNoteChanged: {
    if (!openNote) {
      editorEngaged = false
      focusedNoteId = ""
      return
    }
    if (openNote.id === focusedNoteId) return
    focusedNoteId = openNote.id
    // Deferred so the editor's fields exist to receive it.
    Qt.callLater(function() {
      if (win.openNote && noteEditor) noteEditor.focusForOpen()
    })
  }

  // The deck is centred on the edge and grows from the middle, so adding a
  // note does not shove the others up the screen.
  // Where the fanned column starts, and where the open note's own tab sits in
  // it. The editor lines up with its tab rather than with the screen, so the
  // note reads as having been pulled straight out of the stack.
  readonly property int deckTop: Math.round((height - deckHeight) / 2)

  readonly property int openTabCenter: {
    if (!openNote) return Math.round(height / 2)
    var index = Notes.indexOfId(slice.visible, openNote.id)
    if (index === -1) return Math.round(height / 2)
    return deckTop + index * (tabHeight + 4) + Math.round(tabHeight / 2)
  }

  readonly property int deckHeight: {
    var count = slice.visible.length
    if (count === 0) return fanned ? tabHeight : dashHeight
    return fanned
      ? count * tabHeight + (count - 1) * 4
      : count * dashHeight + (count - 1) * 6
  }

  // ------------------------------------------------------- reach + hover

  // The strip the pointer crosses on its way to the edge. Wider than the
  // visible pill so the deck answers a reach rather than a bullseye.
  Item {
    id: reachStrip
    width: win.fanned ? 0 : win.reachWidth
    height: win.deckHeight + 40
    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
  }

  HoverHandler {
    id: deckHover
    onHoveredChanged: {
      if (hovered) { leaveTimer.stop(); win.fanOpen() }
      else leaveTimer.restart()
    }
  }

  // ---------------------------------------------------------------- deck

  Item {
    id: deckSurface
    width: win.fanned ? win.tabWidth : (win.dashWidth + 10)
    height: win.deckHeight + (win.fanned ? 0 : 10)
    anchors { right: parent.right; verticalCenter: parent.verticalCenter }

    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // The pill body, only at rest: a translucent lozenge holding the dashes.
    Rectangle {
      anchors.fill: parent
      radius: 8
      color: Qt.rgba(0, 0, 0, 0.28)
      opacity: win.fanned ? 0 : 1
      visible: opacity > 0
      Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    Column {
      id: deckColumn
      anchors { right: parent.right; verticalCenter: parent.verticalCenter }
      anchors.rightMargin: win.fanned ? 0 : 5
      spacing: win.fanned ? 4 : 6

      Repeater {
        model: win.slice.visible

        // One note: a dash in the pill, a tab in the fan. The same item
        // morphs between the two so the fan reads as the pill opening up.
        Item {
          id: tab
          required property var modelData
          required property int index

          readonly property var paper: Notes.palette(modelData.color)
          readonly property color paperColor: paper.paper
          readonly property color inkColor: paper.ink
          readonly property color ruleColor: paper.rule
          readonly property bool isOpen: win.host && win.host.openNoteId === modelData.id
          readonly property bool cursored: win.keyboardDriving
            && win.cursorIndex === win.deckOffset + index

          width: win.fanned ? win.tabWidth : win.dashWidth
          height: win.fanned ? win.tabHeight : win.dashHeight

          // The 45ms cascade: each tab waits its turn on the way out and on
          // the way back, which is what makes it read as a deck fanning
          // rather than a panel resizing.
          Behavior on width {
            SequentialAnimation {
              PauseAnimation { duration: tab.index * 45 }
              NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
            }
          }
          Behavior on height {
            SequentialAnimation {
              PauseAnimation { duration: tab.index * 45 }
              NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
            }
          }

          Rectangle {
            id: tabPaper
            anchors.fill: parent
            // The cursor starts the tab out of the deck: the same movement
            // opening it finishes, so the highlight means something.
            anchors.leftMargin: tab.cursored ? -10 : 0
            // Flush to the screen edge: only the left corners are rounded.
            topLeftRadius: win.fanned ? 12 : 4
            bottomLeftRadius: win.fanned ? 12 : 4
            topRightRadius: win.fanned ? 0 : 4
            bottomRightRadius: win.fanned ? 0 : 4
            color: tab.paperColor
            opacity: tab.isOpen ? 0.55 : 1

            Behavior on anchors.leftMargin {
              NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
            }

            layer.enabled: win.fanned
            layer.effect: MultiEffect {
              shadowEnabled: true
              shadowBlur: 0.6
              shadowHorizontalOffset: -2
              shadowOpacity: tab.cursored ? 0.5 : 0.3
            }
          }

          // The note's margin rule, carried into the tab.
          Rectangle {
            visible: win.fanned
            width: 1
            anchors { right: parent.right; rightMargin: 8; top: parent.top; bottom: parent.bottom; topMargin: 10; bottomMargin: 10 }
            color: Util.alpha(tab.ruleColor, 0.6)
          }

          Text {
            visible: win.fanned
            opacity: win.fanned ? 1 : 0
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -4
            rotation: -90
            width: tab.height - 20
            horizontalAlignment: Text.AlignHCenter
            text: Notes.titleOf(tab.modelData).toUpperCase()
            elide: Text.ElideRight
            maximumLineCount: 1
            color: Util.alpha(tab.inkColor, 0.7)
            font.family: Style.font.family
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 2
            Behavior on opacity { NumberAnimation { duration: 120 } }
          }

          TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            acceptedButtons: Qt.LeftButton
            onTapped: win.noteTapped(tab.modelData.id)
          }

          TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            acceptedButtons: Qt.RightButton
            onTapped: function(point) { menuPopup.openFor(tab.modelData.id, point.scenePosition) }
          }
        }
      }

      // An empty deck has no dashes to draw, and a dark lozenge on a dark
      // wallpaper is not an affordance. One dash in the theme accent stands in
      // for the notes that are not there yet: it says the deck lives here, and
      // reaching for it offers a first note.
      Rectangle {
        visible: win.slice.visible.length === 0 && !win.fanned
        width: win.dashWidth
        height: win.dashHeight
        radius: 4
        color: Color.accent
      }

      // Fanned and empty, the accent dash becomes the note that is not there:
      // a tab-shaped outline that writes one when tapped. The round + below
      // does the same thing, but a tab is the shape the eye is looking for.
      Item {
        id: ghostTab
        visible: win.slice.visible.length === 0 && win.fanned
        width: win.tabWidth
        height: win.tabHeight

        Rectangle {
          anchors.fill: parent
          topLeftRadius: 12
          bottomLeftRadius: 12
          color: Util.alpha(Color.accent, ghostHover.hovered ? 0.28 : 0.16)
          border.width: 1
          border.color: Util.alpha(Color.accent, ghostHover.hovered ? 0.9 : 0.55)
        }

        Text {
          anchors.centerIn: parent
          rotation: -90
          width: ghostTab.height - 20
          horizontalAlignment: Text.AlignHCenter
          text: win.host.t("deck.ghostTab")
          elide: Text.ElideRight
          maximumLineCount: 1
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: 11
          font.bold: true
          font.letterSpacing: 2
        }

        HoverHandler { id: ghostHover }
        TapHandler {
          gesturePolicy: TapHandler.ReleaseWithinBounds
          onTapped: win.host.newNote()
        }
      }

      // "+N more": the tail of the deck, scrolled through in place.
      Rectangle {
        visible: win.fanned && win.slice.overflow > 0
        width: win.tabWidth
        height: 28
        topLeftRadius: 10
        bottomLeftRadius: 10
        color: Qt.rgba(0, 0, 0, 0.35)

        Text {
          anchors.centerIn: parent
          text: "+" + win.slice.overflow
          color: "#f4f1e8"
          font.family: Style.font.family
          font.pixelSize: 10
          font.bold: true
        }

        HoverHandler { id: overflowHover }

        PanelToolTip {
          visible: overflowHover.hovered
          text: win.host.t("deck.more", { n: win.slice.overflow })
        }

        TapHandler {
          gesturePolicy: TapHandler.ReleaseWithinBounds
          onTapped: win.deckOffset = win.deckOffset + win.effectiveLimit >= win.slice.total
            ? 0 : win.deckOffset + 1
        }
      }
    }

    WheelHandler {
      enabled: win.fanned && win.slice.overflow > 0
      onWheel: function(event) {
        win.deckOffset = Math.max(0, Math.min(win.slice.total - win.effectiveLimit,
          win.deckOffset + (event.angleDelta.y > 0 ? -1 : 1)))
      }
    }

    TapHandler {
      gesturePolicy: TapHandler.ReleaseWithinBounds
      acceptedButtons: Qt.RightButton
      onTapped: function(point) { menuPopup.openFor("", point.scenePosition) }
    }
  }

  // A new note, one click from the deck.
  Rectangle {
    id: plusButton
    width: win.fanned ? 34 : 0
    height: win.fanned ? 34 : 0
    radius: 17
    visible: win.fanned
    color: plusHover.hovered ? "#ffffff" : Qt.rgba(1, 1, 1, 0.82)
    anchors {
      right: parent.right
      rightMargin: 8
      top: deckSurface.bottom
      topMargin: 12
    }

    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowBlur: 0.6
      shadowOpacity: 0.3
    }

    Text {
      anchors.centerIn: parent
      text: "+"
      color: "#3a3a38"
      font.family: Style.font.family
      font.pixelSize: 18
    }

    HoverHandler { id: plusHover }

    PanelToolTip {
      visible: plusHover.hovered
      text: win.host.t("deck.newNote")
    }

    TapHandler {
      gesturePolicy: TapHandler.ReleaseWithinBounds
      onTapped: win.host.newNote()
    }
  }

  // -------------------------------------------------------------- editor

  Item {
    id: editorHolder
    width: win.openNote ? win.editorWidth : 0
    height: win.openNote ? win.editorHeight : 0
    anchors.right: parent.right
    anchors.rightMargin: win.tabWidth - 6
    // Clamped so a note opened from the top or bottom of the deck still
    // shows whole.
    y: Math.max(12, Math.min(win.height - height - 12,
       win.openTabCenter - Math.round(height / 2)))
    visible: win.openNote !== null

    Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // Slides clear of the deck rather than appearing next to it.
    opacity: win.openNote ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 130 } }

    HoverHandler {
      id: editorHover
      onHoveredChanged: if (hovered) leaveTimer.stop(); else leaveTimer.restart()
    }

    TapHandler {
      gesturePolicy: TapHandler.ReleaseWithinBounds
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      // Any click in the note means the user is working in it, so the fan
      // closing must not take it away.
      onTapped: win.editorEngaged = true
    }

    NoteEditor {
      id: noteEditor
      anchors.fill: parent
      host: win.host
      store: win.store
      note: win.openNote
      onCloseRequested: win.host.closeNote()
      onEditingChanged: if (editing) win.editorEngaged = true
    }
  }

  // --------------------------------------------------------------- toast

  // Ten seconds to change your mind about a delete.
  Rectangle {
    id: toast
    readonly property int pendingCount: win.host ? win.host.pendingDeletes.length : 0
    readonly property bool showing: win.isOpenScreen && pendingCount > 0
    width: showing ? 220 : 0
    height: showing ? 38 : 0
    visible: showing
    radius: 10
    color: Qt.rgba(0, 0, 0, 0.82)
    anchors { right: parent.right; rightMargin: 14; bottom: parent.bottom; bottomMargin: 40 }

    Row {
      anchors.centerIn: parent
      spacing: 12

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: win.host.tn("toast.deleted", toast.pendingCount)
        color: "#f4f1e8"
        font.family: Style.font.family
        font.pixelSize: 11
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 54
        height: 22
        radius: 6
        color: undoHover.hovered ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.16)

        Text {
          anchors.centerIn: parent
          text: win.host.t("toast.undo")
          color: "#f4f1e8"
          font.family: Style.font.family
          font.pixelSize: 11
          font.bold: true
        }

        HoverHandler { id: undoHover }
        TapHandler {
          gesturePolicy: TapHandler.ReleaseWithinBounds
          onTapped: win.host.undoDelete()
        }
      }
    }
  }

  // ---------------------------------------------------------------- menu

  Rectangle {
    id: menuPopup

    property bool open: false
    property string noteId: ""

    function openFor(id, scenePos) {
      noteId = id || ""
      open = true
      y = Math.max(8, Math.min(win.height - height - 8, scenePos.y - 10))
    }

    function dismiss() { open = false; noteId = "" }

    readonly property var menuItems: {
          var items = []
          if (menuPopup.noteId !== "") {
            items.push({ label: win.host.t("menu.openNote"), action: "open" })
            items.push({ label: win.host.t("menu.cycleColour"), action: "color" })
            items.push({ label: win.host.t("menu.archiveNote"), action: "archive" })
            items.push({ label: win.host.t("menu.deleteNote"), action: "delete", danger: true })
            items.push({ label: "", action: "" })
          }
          items.push({ label: win.host.t("menu.newNote"), action: "new" })
          items.push({ label: win.host.t("menu.allNotes"), action: "all" })
          items.push({ label: win.host.t("menu.archive"), action: "archived" })
          items.push({ label: win.host.t("menu.shortcuts"), action: "shortcuts" })
          items.push({ label: win.host.t("menu.about"), action: "about" })
          items.push({ label: "", action: "" })
          items.push({
            label: (win.host && win.host.overFullscreen ? "✓ " : "   ")
              + win.host.t("menu.overFullscreen"),
            action: "fullscreen"
          })
          items.push({ label: "", action: "" })
          items.push({ label: win.host.t("menu.orderHeading"), action: "", heading: true })
          var orders = [
            { key: "recent", label: win.host.t("menu.order.recent") },
            { key: "manual", label: win.host.t("menu.order.manual") },
            { key: "oldest", label: win.host.t("menu.order.oldest") }
          ]
          for (var i = 0; i < orders.length; i++) {
            items.push({
              label: ((win.host && win.host.deckOrder === orders[i].key) ? "✓ " : "   ") + orders[i].label,
              action: "order:" + orders[i].key
            })
          }
          items.push({ label: "", action: "" })
          items.push({ label: win.host.t("menu.languageHeading"), action: "", heading: true })
          for (var l = 0; l < Strings.LANGUAGE_CHOICES.length; l++) {
            var choice = Strings.LANGUAGE_CHOICES[l]
            items.push({
              label: ((win.host && win.host.languageSetting === choice.key) ? "✓ " : "   ")
                + choice.label,
              action: "lang:" + choice.key
            })
          }
          return items
    }

    // A menu of monospace labels is exactly as wide as its longest one; a
    // fixed width either wastes space or crowds "Show over full-screen apps"
    // against its own border.
    readonly property string widestLabel: {
      var longest = ""
      for (var i = 0; i < menuItems.length; i++)
        if (String(menuItems[i].label).length > longest.length) longest = String(menuItems[i].label)
      return longest
    }

    TextMetrics {
      id: menuMetrics
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      text: menuPopup.widestLabel
    }

    visible: open
    width: open ? Math.max(210, Math.ceil(menuMetrics.advanceWidth) + 30) : 0
    height: open ? menuColumn.implicitHeight + 12 : 0
    anchors.right: parent.right
    anchors.rightMargin: 10
    radius: 10
    color: Color.popups.background
    border.width: 1
    border.color: Util.alpha(Color.popups.border, 0.5)

    Column {
      id: menuColumn
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }

      Repeater {
        model: menuPopup.menuItems

        Item {
          id: menuRow
          required property var modelData
          width: menuColumn.width
          height: modelData.heading === true ? 22 : (modelData.action === "" ? 7 : 26)

          Text {
            visible: menuRow.modelData.heading === true
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            text: menuRow.modelData.label
            color: Util.alpha(Color.popups.text, 0.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Rectangle {
            visible: menuRow.modelData.action === "" && menuRow.modelData.heading !== true
            height: 1
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 4 }
            color: Util.alpha(Color.popups.text, 0.15)
          }

          Rectangle {
            visible: menuRow.modelData.action !== ""
            anchors.fill: parent
            radius: 6
            color: rowHover.hovered ? Util.alpha(Color.popups.text, 0.1) : "transparent"

            Text {
              anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
              text: menuRow.modelData.label
              color: menuRow.modelData.danger === true ? Color.urgent : Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }

          HoverHandler { id: rowHover }

          TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            enabled: menuRow.modelData.action !== ""
            onTapped: {
              var action = menuRow.modelData.action
              var id = menuPopup.noteId
              menuPopup.dismiss()
              if (action === "open") win.noteTapped(id)
              else if (action === "color") win.store.cycleColor(id)
              else if (action === "archive") win.host.archiveNote(id)
              else if (action === "delete") win.host.deleteNote(id)
              else if (action === "new") win.host.newNote()
              else if (action === "all") win.host.showAllNotes("all")
              else if (action === "archived") win.host.showAllNotes("archived")
              else if (action === "shortcuts") win.host.showShortcuts()
              else if (action === "about") win.host.showAbout()
              else if (action === "fullscreen") {
                win.host.overFullscreen = !win.host.overFullscreen
                win.host.saveSettings()
              }
              else if (action.indexOf("lang:") === 0) {
                win.host.setLanguage(action.substring(5))
              }
              else if (action.indexOf("order:") === 0) {
                win.deckOffset = 0
                win.host.setDeckOrder(action.substring(6))
              }
            }
          }
        }
      }
    }

    // A menu left open while the deck folds away would sit alone on the edge.
    Connections {
      target: win
      function onFannedChanged() { if (!win.fanned) menuPopup.dismiss() }
    }
  }
}
