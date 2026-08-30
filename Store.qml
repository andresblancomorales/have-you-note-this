import QtQuick
import Quickshell
import Quickshell.Io
import "Notes.js" as Notes

// The note store, seen from QML: one long-lived helper process speaking
// line-delimited JSON. Reads and writes are async, but every mutation patches
// the local array first, so typing never waits on a round trip and the deck
// never redraws a stale note between keystroke and reply.
Item {
  id: root

  // Absolute path to bin/notethis-store.
  property string helper: ""

  property var notes: []
  property bool ready: false
  // "keyring" when the master key sits in libsecret, "file" when there was no
  // keyring to talk to. The All Notes privacy line reports which.
  property string keyStorage: ""
  // Where the database actually sits, for the About card to quote.
  property string dbPath: ""
  property string lastError: ""

  property int _nextId: 1
  property var _pending: ({})

  function _send(op, args, callback) {
    if (!proc.running) {
      root.lastError = "note store is not running"
      if (callback) callback(null, root.lastError)
      return
    }
    var id = root._nextId++
    if (callback) root._pending[id] = callback
    proc.write(JSON.stringify({ id: id, op: op, args: args || {} }) + "\n")
  }

  function _onLine(line) {
    var reply
    try {
      reply = JSON.parse(line)
    } catch (error) {
      console.warn("notethis: unparsable reply:", line)
      return
    }
    var callback = root._pending[reply.id]
    if (callback) delete root._pending[reply.id]
    if (reply.ok) {
      root.lastError = ""
      if (callback) callback(reply.result, null)
    } else {
      root.lastError = reply.error || "note store error"
      console.warn("notethis:", root.lastError)
      if (callback) callback(null, root.lastError)
    }
  }

  // ------------------------------------------------------------- queries

  function note(id) { return Notes.findById(root.notes, id) }

  function refresh(callback) {
    _send("list", {}, function(result, error) {
      if (!error && result) root.notes = result
      if (callback) callback(result, error)
    })
  }

  // Replace one note in the local array. Assigning a new array is what makes
  // the bindings re-evaluate; mutating in place would not.
  function _patch(id, fields) {
    var next = root.notes.slice()
    var index = Notes.indexOfId(next, id)
    if (index === -1) return
    var merged = {}
    for (var key in next[index]) merged[key] = next[index][key]
    for (var field in fields) merged[field] = fields[field]
    next[index] = merged
    root.notes = next
  }

  function _replace(note) {
    if (!note) return
    var index = Notes.indexOfId(root.notes, note.id)
    if (index === -1) {
      root.notes = root.notes.concat([note])
      return
    }
    var next = root.notes.slice()
    next[index] = note
    root.notes = next
  }

  // ----------------------------------------------------------- mutations

  function create(fields, callback) {
    var args = fields || {}
    if (!args.color) args.color = Notes.suggestColor(root.notes)
    _send("create", args, function(result, error) {
      if (!error && result) root._replace(result)
      if (callback) callback(result, error)
    })
  }

  function update(id, fields, callback) {
    if (!id) return
    var args = {}
    for (var key in fields) args[key] = fields[key]
    args.id = id
    // Optimistic: show the change now, reconcile with the stored row on reply.
    var local = {}
    for (var field in fields) if (field !== "touch") local[field] = fields[field]
    _patch(id, local)
    _send("update", args, function(result, error) {
      if (!error && result) root._replace(result)
      if (callback) callback(result, error)
    })
  }

  function remove(id, callback) {
    var next = []
    for (var i = 0; i < root.notes.length; i++)
      if (root.notes[i].id !== id) next.push(root.notes[i])
    root.notes = next
    _send("delete", { id: id }, callback)
  }

  // Deleting with an undo window means the row must survive until the window
  // closes, so the caller holds the note and re-creates it on undo.
  function restore(note, callback) {
    if (!note) return
    _send("create", {
      title: note.title, body: note.body, color: note.color
    }, function(result, error) {
      if (!error && result) {
        root._replace(result)
        if (note.state === "archived")
          root.update(result.id, { state: "archived", touch: false })
      }
      if (callback) callback(result, error)
    })
  }

  function setState(id, state) { update(id, { state: state, touch: false }) }

  function cycleColor(id) {
    var note = root.note(id)
    if (note) update(id, { color: Notes.cycleColor(note.color), touch: false })
  }

  function reorder(ids, callback) {
    var byId = {}
    for (var i = 0; i < root.notes.length; i++) byId[root.notes[i].id] = root.notes[i]
    var next = []
    for (var j = 0; j < ids.length; j++) if (byId[ids[j]]) next.push(byId[ids[j]])
    for (var k = 0; k < root.notes.length; k++)
      if (ids.indexOf(root.notes[k].id) === -1) next.push(root.notes[k])
    root.notes = next
    _send("reorder", { ids: ids }, callback)
  }

  function exportNotes(ids, format, target, callback) {
    _send("export", { ids: ids, format: format, target: target }, callback)
  }

  function importArchive(path, callback) {
    _send("import", { path: path }, function(result, error) {
      if (!error) root.refresh()
      if (callback) callback(result, error)
    })
  }

  // ------------------------------------------------------------- process

  Process {
    id: proc
    // setpriv --pdeathsig keeps the helper from outliving the shell if the
    // shell is killed rather than asked to quit.
    command: root.helper === "" ? [] : ["setpriv", "--pdeathsig", "TERM", root.helper]
    running: root.helper !== ""
    stdinEnabled: true

    stdout: SplitParser { onRead: function(line) { root._onLine(line) } }
    stderr: SplitParser {
      onRead: function(line) { if (line !== "") console.warn("notethis-store:", line) }
    }

    onStarted: {
      root._send("hello", {}, function(result, error) {
        if (error || !result) return
        root.keyStorage = result.keyStorage || ""
        root.dbPath = result.db || ""
        root.ready = true
        root.refresh()
      })
    }

    onExited: function(code, status) {
      root.ready = false
      console.warn("notethis: note store exited (" + code + "), restarting")
      restartTimer.restart()
    }
  }

  Timer {
    id: restartTimer
    interval: 2000
    onTriggered: if (!proc.running && root.helper !== "") proc.running = true
  }
}
