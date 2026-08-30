import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui
import "Notes.js" as Notes

// One note, opened where it sits: the card that slides clear of the deck.
// It keeps the deck's vertical tab down its left edge so the note reads as
// the same object that was in the stack, just pulled out far enough to write
// in. Typing writes itself to disk 250ms after the last keystroke.
Item {
  id: editor

  property var host: null
  property var store: null
  property var note: null

  readonly property var paper: Notes.palette(note ? note.color : "yellow")
  readonly property color paperColor: paper.paper
  readonly property color inkColor: paper.ink
  readonly property color ruleColor: paper.rule
  readonly property int tabWidth: 34
  readonly property int pad: 16
  // The strip along the bottom of the card that belongs to the hint and the
  // action buttons. The body has to end above it: a Flickable that fills to
  // the card's edge will happily scroll text underneath them.
  readonly property int footerHeight: 24

  signal closeRequested()

  // Delete asks twice. The ten-second undo catches the mistake after the
  // fact; this catches it before, which is the difference between "that was
  // close" and "where did my note go".
  property bool deleteArmed: false

  function requestDelete() {
    if (!editor.note) return
    if (editor.deleteArmed) {
      editor.deleteArmed = false
      disarmTimer.stop()
      editor.host.deleteNote(editor.note.id)
      return
    }
    editor.deleteArmed = true
    disarmTimer.restart()
  }

  Timer {
    id: disarmTimer
    interval: 3000
    onTriggered: editor.deleteArmed = false
  }

  // Arming on one note and firing on another would be the worst possible
  // outcome of a confirmation step.
  onNoteChanged: {
    editor.deleteArmed = false
    disarmTimer.stop()
  }

  implicitWidth: 400
  implicitHeight: 320

  // Editing lives in NoteFields, shared with the All Notes reading pane.
  function flush() { fields.flush() }
  function focusBody() { fields.focusBody() }
  function focusTitle() { fields.focusTitle() }
  function focusForOpen() { fields.focusForOpen() }
  function openFind() { fields.openFind() }

  // True once the caret is in the note -- the deck folding away must not take
  // an open note with it while it is being written in.
  readonly property bool editing: fields.editing

  // ------------------------------------------------------------- surface

  Rectangle {
    id: card
    anchors.fill: parent
    radius: 16
    color: editor.paperColor
    antialiasing: true

    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowBlur: 0.8
      shadowVerticalOffset: 4
      shadowOpacity: 0.35
    }

    // The tab the note carried in the deck, still on its left edge.
    Item {
      id: tab
      width: editor.tabWidth
      anchors { left: parent.left; top: parent.top; bottom: parent.bottom }

      Text {
        anchors.centerIn: parent
        rotation: -90
        width: card.height - editor.pad * 2
        horizontalAlignment: Text.AlignHCenter
        text: Notes.titleOf(editor.note).toUpperCase()
        elide: Text.ElideRight
        maximumLineCount: 1
        color: Util.alpha(editor.inkColor, 0.65)
        font.family: Style.font.family
        font.pixelSize: 11
        font.letterSpacing: 2
        font.bold: true
      }
    }

    // The card's margin rule, the same dashed line the tab shows in the deck.
    Canvas {
      id: rule
      x: editor.tabWidth
      width: 1
      anchors { top: parent.top; bottom: parent.bottom; topMargin: 10; bottomMargin: 10 }
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = editor.ruleColor
        ctx.globalAlpha = 0.7
        ctx.lineWidth = 1
        ctx.setLineDash([4, 4])
        ctx.beginPath()
        ctx.moveTo(0.5, 0)
        ctx.lineTo(0.5, height)
        ctx.stroke()
      }
    }

    NoteFields {
      id: fields
      anchors {
        left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom
        leftMargin: editor.tabWidth + editor.pad
        rightMargin: editor.pad
        topMargin: editor.pad
        bottomMargin: editor.pad + editor.footerHeight
      }
      store: editor.store
      note: editor.note
      host: editor.host
      ink: editor.inkColor
      rule: editor.ruleColor
      onEscaped: editor.closeRequested()
    }

    // Actions the shortcuts also cover, shown on hover so they are findable
    // without reading the FAQ.
    Row {
      id: actions
      anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
      spacing: 4
      // Armed from the keyboard, the row has to be on screen to say so --
      // otherwise the confirmation is invisible to the person confirming.
      opacity: (cardHover.hovered || editor.deleteArmed) ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 120 } }

      Repeater {
        model: [
          { glyph: "◐", tip: editor.host.t("note.action.colour"), action: "color", danger: false, gap: false },
          // A box with an arrow going into it, not the lidded bin the plain
          // archive glyph draws -- next to a delete button, anything bin
          // shaped reads as "this destroys the note".
          { glyph: "󱉚", tip: editor.host.t("note.action.archive"),
            action: "archive", danger: false, gap: false },
          // The bin belongs here, and only here, in red and set apart: the
          // destructive button should be the one that looks destructive.
          { glyph: "󰩹", tip: "", action: "delete", danger: true, gap: true }
        ]

        // A slot rather than a bare circle: a Row positions its children and
        // ignores their anchors, so the space that sets delete apart has to be
        // part of the item's own width.
        Item {
          id: actionSlot
          required property var modelData

          readonly property bool danger: modelData.danger === true
          // Fixed red rather than the paper's ink or the theme's urgent
          // colour: this button sits on coloured paper, where a theme red can
          // land on pink or orange and vanish. Destructive has to read the
          // same on all six papers. The All Notes window, whose chrome is the
          // theme's, uses Color.urgent there.
          readonly property color dangerInk: "#A33A2A"

          width: 22 + (modelData.gap === true ? 8 : 0)
          height: 22

          Rectangle {
            id: actionButton
            anchors.right: parent.right
            width: 22
            height: 22
            radius: 11
            readonly property bool armed: actionSlot.danger && editor.deleteArmed
            color: actionSlot.danger
              ? Util.alpha(actionSlot.dangerInk,
                  armed ? 0.85 : (iconHover.hovered ? 0.3 : 0.15))
              : Qt.rgba(1, 1, 1, iconHover.hovered ? 0.55 : 0.28)

            Text {
              anchors.centerIn: parent
              text: actionSlot.modelData.glyph
              font.family: Style.font.family
              font.pixelSize: 12
              color: actionButton.armed
                ? "#FFFFFF"
                : (actionSlot.danger ? actionSlot.dangerInk : Util.alpha(editor.inkColor, 0.8))
            }

            HoverHandler { id: iconHover }

            PanelToolTip {
              visible: iconHover.hovered
              text: actionSlot.danger
                ? editor.host.t(editor.deleteArmed ? "note.action.deleteArmed" : "note.action.delete")
                : actionSlot.modelData.tip
            }

            TapHandler {
              gesturePolicy: TapHandler.ReleaseWithinBounds
              onTapped: {
                if (!editor.note) return
                if (actionSlot.modelData.action === "color") editor.store.cycleColor(editor.note.id)
                else if (actionSlot.modelData.action === "archive") editor.host.archiveNote(editor.note.id)
                else editor.requestDelete()
              }
            }
          }
        }
      }
    }

    // The open note holds the keyboard, so the way out has to be visible
    // while it does. Only while the caret is actually in the note: a hint
    // that is always up stops being a hint.
    Text {
      anchors { left: parent.left; bottom: parent.bottom; leftMargin: editor.tabWidth + editor.pad; bottomMargin: 12 }
      visible: editor.editing
      text: editor.host.t("note.escToClose")
      color: Util.alpha(editor.inkColor, 0.4)
      font.family: Style.font.family
      font.pixelSize: 10
    }

    HoverHandler { id: cardHover }
  }

  // ----------------------------------------------------------- shortcuts
  //
  // Bound on the card rather than on each field so they fire wherever the
  // caret is. Ctrl stands in for the Mac app's Command.
  Shortcut {
    sequences: ["Ctrl+F"]
    enabled: editor.visible
    onActivated: fields.openFind()
  }
  Shortcut {
    sequences: ["Ctrl+."]
    enabled: editor.visible
    onActivated: if (editor.note) editor.store.cycleColor(editor.note.id)
  }
  Shortcut {
    sequences: ["Ctrl+Backspace"]
    enabled: editor.visible
    onActivated: editor.requestDelete()
  }
  Shortcut {
    sequences: ["Ctrl+Shift+A"]
    enabled: editor.visible
    onActivated: if (editor.note) editor.host.archiveNote(editor.note.id)
  }
  Shortcut {
    sequences: ["Esc"]
    enabled: editor.visible
    onActivated: {
      if (fields.findOpen) fields.closeFind()
      else { fields.flush(); editor.closeRequested() }
    }
  }
}
