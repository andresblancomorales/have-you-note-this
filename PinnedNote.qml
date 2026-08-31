import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Notes.js" as Notes

// A note peeled off the deck and kept on top.
//
// The deck is for the notes you are working through; this is for the one you
// want in front of you whatever you are doing. It sits on the `top` layer,
// above the windows.
//
// The wallpaper would be the prettier metaphor -- a sticky note belongs on the
// desk, not on the work -- but this runs on a tiling window manager, where the
// desktop is covered nearly all of the time. A note you cannot see is not a
// note. It stays under fullscreen windows, so a video or a game still gets the
// screen to itself.
PanelWindow {
  id: pin

  property var host: null
  property var store: null

  // The window is handed an id and finds the note itself, so a note being
  // rewritten does not mean a window being rebuilt.
  property string noteId: ""
  readonly property var note: (store && noteId !== "") ? store.note(noteId) : null

  screen: {
    var screens = Quickshell.screens
    var wanted = note ? note.pinScreen : ""
    for (var i = 0; i < screens.length; i++)
      if (screens[i].name === wanted) return screens[i]
    // A note whose screen is gone comes back on the first one, not nowhere.
    return screens.length > 0 ? screens[0] : null
  }

  readonly property var paper: Notes.palette(note ? note.color : "yellow")
  readonly property color paperColor: paper.paper
  readonly property color inkColor: paper.ink
  readonly property color ruleColor: paper.rule

  readonly property int cardWidth: 260
  readonly property int cardHeight: 200
  readonly property int pad: 14

  // The surface spans the screen and the card is placed inside it, rather
  // than the surface being moved: a layer-shell window cannot be dragged, but
  // an item within one can.
  anchors { top: true; left: true; right: true; bottom: true }
  color: "transparent"
  WlrLayershell.namespace: "notethis-pinned"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  exclusionMode: ExclusionMode.Ignore

  // Only the card takes input; the rest of the desktop is untouched.
  mask: Region { item: card }

  function commitPosition() {
    if (!note || !store) return
    store.update(note.id, {
      pinX: card.x, pinY: card.y, pinScreen: pin.screenName, touch: false
    })
  }

  readonly property string screenName: screen ? screen.name : ""


  Rectangle {
    id: card
    width: pin.cardWidth
    height: pin.cardHeight
    radius: 14
    color: pin.paperColor
    antialiasing: true

    // Where the user dropped it, clamped so a note cannot be lost off-screen
    // when a monitor is unplugged or the resolution changes.
    x: Math.max(0, Math.min(pin.width - width, pin.note ? pin.note.pinX : 80))
    y: Math.max(0, Math.min(pin.height - height, pin.note ? pin.note.pinY : 80))

    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowBlur: 0.7
      shadowVerticalOffset: 3
      shadowOpacity: 0.35
    }

    // The card cannot be dragged from anywhere: the text field takes the press
    // first, because inside a note a press is a caret. So the top of the card
    // is a grip -- the strip you would actually reach for to move a piece of
    // paper, and the one place there is nothing to type into.
    Item {
      id: grip
      height: 22
      anchors { left: parent.left; right: parent.right; top: parent.top }

      Row {
        anchors.centerIn: parent
        spacing: 3

        Repeater {
          model: 3
          Rectangle {
            width: 3
            height: 3
            radius: 1.5
            color: Util.alpha(pin.inkColor, gripHover.hovered ? 0.55 : 0.3)
          }
        }
      }

      HoverHandler {
        id: gripHover
        cursorShape: Qt.OpenHandCursor
      }

      DragHandler {
        id: drag
        target: card
        xAxis.minimum: 0
        xAxis.maximum: pin.width - card.width
        yAxis.minimum: 0
        yAxis.maximum: pin.height - card.height
        cursorShape: Qt.ClosedHandCursor
        onActiveChanged: if (!active) pin.commitPosition()
      }
    }

    // The margin around the writing is draggable too, so the grip is the
    // obvious handle rather than the only one. Presses inside the fields
    // still reach them first -- there a press is a caret.
    DragHandler {
      target: card
      xAxis.minimum: 0
      xAxis.maximum: pin.width - card.width
      yAxis.minimum: 0
      yAxis.maximum: pin.height - card.height
      cursorShape: Qt.ClosedHandCursor
      onActiveChanged: if (!active) pin.commitPosition()
    }

    NoteFields {
      anchors {
        fill: parent
        leftMargin: pin.pad
        rightMargin: pin.pad
        topMargin: grip.height
        bottomMargin: pin.pad
      }
      host: pin.host
      store: pin.store
      note: pin.note
      ink: pin.inkColor
      rule: pin.ruleColor
      titleSize: Style.font.subtitle
      showEdited: false
    }

    // Unpin: back to the deck, where it came from.
    Rectangle {
      anchors { right: grip.right; verticalCenter: grip.verticalCenter; rightMargin: 6 }
      width: 18
      height: 18
      radius: 9
      opacity: cardHover.hovered ? 1 : 0
      color: unpinHover.hovered ? Util.alpha(pin.inkColor, 0.22) : Util.alpha(pin.inkColor, 0.1)
      Behavior on opacity { NumberAnimation { duration: 120 } }

      Text {
        anchors.centerIn: parent
        text: "󰐄"
        font.family: Style.font.family
        font.pixelSize: 11
        color: Util.alpha(pin.inkColor, 0.8)
      }

      HoverHandler { id: unpinHover }

      PanelToolTip {
        visible: unpinHover.hovered
        text: pin.host ? pin.host.t("note.action.unpin") : ""
      }

      TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        // Invisible and still clickable is how a corner of a note becomes a
        // trapdoor. It answers only while it is showing itself.
        enabled: cardHover.hovered
        onTapped: if (pin.host && pin.note) pin.host.unpinNote(pin.note.id)
      }
    }

    HoverHandler { id: cardHover }

    // The same key that stuck it here takes it back.
    Shortcut {
      sequences: ["Ctrl+P"]
      onActivated: if (pin.host && pin.note) pin.host.unpinNote(pin.note.id)
    }
  }
}
