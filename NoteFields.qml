import QtQuick
import qs.Commons
import "Notes.js" as Notes

// The writable part of a note: its title, its body, and the find bar between
// them. Shared by the card that lifts out of the deck and the reading pane in
// All Notes, so a note edited in either place is edited the same way -- one
// debounce, one flush rule, one answer to "what happens to what I typed when
// I switch notes".
//
// Colours and sizes come from the caller: the deck's card writes on coloured
// paper, the window's pane writes on the same paper inside themed chrome.
Item {
  id: fields

  property var store: null
  property var note: null
  property var host: null

  property color ink: Color.foreground
  property color rule: Color.accent
  property int titleSize: Style.font.title
  property int bodySize: Style.font.subtitle
  property bool showEdited: true

  // True while the caret is in the note. Callers use it to decide whether the
  // note is being worked in -- the deck will not fold an engaged note away.
  readonly property bool editing: titleField.activeFocus || bodyField.activeFocus
    || findField.activeFocus

  // The note whose text is currently in the fields. Not the same thing as
  // `note`, which is a binding over the store and hands back a fresh object on
  // every write-back.
  property string loadedId: ""

  signal escaped()

  Timer {
    id: saveTimer
    interval: 250
    onTriggered: fields.flush()
  }

  // Writes to `loadedId`, not to `note`: by the time a note switch reaches
  // here, `note` is already the new one, and the keystrokes still in the
  // fields belong to the note being left.
  function flush() {
    saveTimer.stop()
    if (!store || loadedId === "") return
    var target = store.note(loadedId)
    if (!target) return
    if (titleField.text === target.title && bodyField.text === target.body) return
    store.update(loadedId, { title: titleField.text, body: bodyField.text })
  }

  function focusBody() { bodyField.forceActiveFocus() }
  function focusTitle() { titleField.forceActiveFocus() }

  // A blank note is named first -- the title is what its tab shows, and an
  // unnamed note is one you cannot find again -- while a note with anything in
  // it opens at its body, where the writing goes.
  function focusForOpen() {
    if (!note) return
    if ((note.title || "") === "" && (note.body || "") === "") titleField.forceActiveFocus()
    else bodyField.forceActiveFocus()
  }

  function openFind() {
    findBar.visible = true
    findField.selectAll()
    findField.forceActiveFocus()
  }

  function closeFind() {
    findBar.visible = false
    bodyField.forceActiveFocus()
  }

  readonly property bool findOpen: findBar.visible

  // What the body needs to show itself whole, so a caller sizing a card to
  // its note has something to size to.
  readonly property real bodyContentHeight: bodyField.contentHeight

  // --------------------------------------------------------- checklists

  // Flip the box on a line, from a click on its marker or from the caret.
  // Written through the store like any other edit, so it lands in the same
  // debounce and shows up wherever else the note is open.
  function toggleCheckAt(position, markerOnly) {
    if (!note || !store) return false
    var next = Notes.toggleChecklistAt(bodyField.text, position, markerOnly)
    if (next === null) return false
    var caret = bodyField.cursorPosition
    bodyField.text = next
    // The flip is the same length, so the caret can go back where it was.
    bodyField.cursorPosition = Math.min(caret, next.length)
    saveTimer.restart()
    return true
  }

  function toggleCheckAtCaret() {
    return toggleCheckAt(bodyField.cursorPosition, false)
  }

  function findNext() {
    var needle = findField.text.toLowerCase()
    if (needle === "") return
    var haystack = bodyField.text.toLowerCase()
    var from = Math.max(bodyField.selectionStart, bodyField.selectionEnd)
    var at = haystack.indexOf(needle, from)
    if (at === -1) at = haystack.indexOf(needle, 0)  // wrap
    if (at === -1) return
    bodyField.forceActiveFocus()
    bodyField.select(at, at + needle.length)
  }

  onNoteChanged: {
    if (note && note.id === loadedId) {
      adoptExternalEdit()
      return
    }
    // Whatever is still in the debounce belongs to the note being left.
    flush()
    loadedId = note ? note.id : ""
    titleField.text = note ? (note.title || "") : ""
    bodyField.text = note ? (note.body || "") : ""
    findBar.visible = false
  }

  // The same note can be open in the deck's card and in the All Notes pane at
  // once, and a note edited in one has to show up in the other. Fields are
  // seeded on load, so without this the second surface keeps showing what the
  // note said when it was opened -- and would write that back over the newer
  // text the next time it flushed.
  //
  // Only fields that are neither focused nor mid-debounce are adopted: an
  // update arriving while someone is typing is our own write-back coming home,
  // and re-seeding then would fight the caret.
  function adoptExternalEdit() {
    if (!note || saveTimer.running) return
    if (!titleField.activeFocus && titleField.text !== (note.title || ""))
      titleField.text = note.title || ""
    if (!bodyField.activeFocus && bodyField.text !== (note.body || ""))
      bodyField.text = note.body || ""
  }

  Component.onDestruction: flush()

  Column {
    anchors.fill: parent
    spacing: 8

    Item {
      width: parent.width
      // Grows with the title, but only so far: on a small pinned card a
      // rambling title should not push the writing off the paper.
      height: Math.max(22, Math.min(titleField.implicitHeight,
        Math.round(fields.titleSize * 3.6)))
      clip: true

      // A TextEdit, not a TextInput: a single line cut a long title off at the
      // edge of the card with nothing to say it had. Titles wrap now, and
      // Return still means "on to the body" rather than a newline.
      TextEdit {
        id: titleField
        anchors {
          left: parent.left
          right: editedStamp.visible ? editedStamp.left : parent.right
          rightMargin: editedStamp.visible ? 8 : 0
          verticalCenter: parent.verticalCenter
        }
        font.family: Style.font.family
        font.pixelSize: fields.titleSize
        font.bold: true
        color: fields.ink
        selectionColor: Util.alpha(fields.rule, 0.6)
        selectedTextColor: fields.ink
        wrapMode: TextEdit.Wrap
        clip: true
        onTextChanged: saveTimer.restart()
        Keys.onReturnPressed: bodyField.forceActiveFocus()
        Keys.onTabPressed: bodyField.forceActiveFocus()

        Text {
          anchors.fill: parent
          visible: titleField.text === "" && !titleField.activeFocus
          text: fields.host ? fields.host.t("note.untitled") : ""
          font: titleField.font
          color: Util.alpha(fields.ink, 0.35)
        }
      }

      Text {
        id: editedStamp
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        visible: fields.showEdited && fields.note !== null
        text: (fields.note && fields.host)
          ? fields.host.t("note.edited", { date: fields.host.shortDate(fields.note.updated) }) : ""
        font.family: Style.font.family
        font.pixelSize: 10
        color: Util.alpha(fields.ink, 0.45)
      }
    }

    // Between the title and the body, so opening it never shifts the body
    // sideways.
    Rectangle {
      id: findBar
      visible: false
      width: parent.width
      height: 24
      radius: 6
      color: Util.alpha(fields.ink, 0.08)

      TextInput {
        id: findField
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        verticalAlignment: TextInput.AlignVCenter
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        color: fields.ink
        selectionColor: Util.alpha(fields.rule, 0.6)
        onTextChanged: fields.findNext()
        Keys.onReturnPressed: fields.findNext()
        Keys.onEscapePressed: fields.closeFind()

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: findField.text === ""
          text: fields.host ? fields.host.t("note.find") : ""
          font: findField.font
          color: Util.alpha(fields.ink, 0.4)
        }
      }
    }

    Flickable {
      id: bodyScroll
      width: parent.width
      height: parent.height - y
      contentWidth: width
      contentHeight: bodyField.contentHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      function ensureVisible(rect) {
        if (contentY >= rect.y) contentY = rect.y
        else if (contentY + height <= rect.y + rect.height)
          contentY = rect.y + rect.height - height
      }

      TextEdit {
        id: bodyField
        width: parent.width
        wrapMode: TextEdit.Wrap
        font.family: Style.font.family
        font.pixelSize: fields.bodySize
        color: fields.ink
        selectionColor: Util.alpha(fields.rule, 0.6)
        selectedTextColor: fields.ink
        persistentSelection: true
        onTextChanged: saveTimer.restart()
        // Keep the caret in view as the note grows past the card.
        onCursorRectangleChanged: bodyScroll.ensureVisible(cursorRectangle)
        Keys.onEscapePressed: fields.escaped()

        // Ctrl+Return ticks the item the caret is on. Return itself has to
        // stay a newline -- this is a text field first.
        Keys.onPressed: function(event) {
          if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
              && (event.modifiers & Qt.ControlModifier)) {
            fields.toggleCheckAtCaret()
            event.accepted = true
          }
        }

        // A tap on the "- [ ]" itself ticks it. Declared before the field's
        // own handlers would place the caret, and it only claims the tap when
        // the box is what was hit -- everywhere else the click is a caret.
        TapHandler {
          gesturePolicy: TapHandler.ReleaseWithinBounds
          onTapped: function(point) {
            var position = bodyField.positionAt(point.position.x, point.position.y)
            fields.toggleCheckAt(position, true)
          }
        }

        Text {
          anchors.fill: parent
          visible: bodyField.text === "" && !bodyField.activeFocus
          text: fields.host ? fields.host.t("note.placeholder") : ""
          font: bodyField.font
          color: Util.alpha(fields.ink, 0.3)
        }
      }
    }
  }
}
