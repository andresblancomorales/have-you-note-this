.pragma library

// Every word the plugin shows, in the languages it speaks.
//
// Not `qsTr()`: Quickshell gives QML no way to install a QTranslator, so Qt's
// own machinery would compile and then do nothing. A table read through `t()`
// is the mechanism that actually works here, and it is testable in node with
// the rest of the pure logic.
//
// Key names are not translated. "Ctrl" and "Super" are what the key caps say
// in every language this speaks; only what the key *does* is a sentence.

var APP_NAME = "Have you note-this?"
var APP_REPO = "https://github.com/andresblancomorales/have-you-note-this"

var LANGUAGES = ["en", "es"]

// What the language menu offers. "auto" first because following the session is
// the right default; each language is named in itself, which is the only name
// its speaker can be relied on to recognise.
var LANGUAGE_CHOICES = [
  { key: "auto", label: "Auto" },
  { key: "en", label: "English" },
  { key: "es", label: "Español" }
]

var STRINGS = {
  en: {

    // -- the deck --------------------------------------------------------
    "deck.newNote": "New note · Super + Alt + N",
    "deck.ghostTab": "NEW NOTE",
    "deck.more": "{n} more · click or scroll the deck",
    "menu.openNote": "Open note",
    "menu.cycleColour": "Cycle colour",
    "menu.archiveNote": "Archive note",
    "menu.deleteNote": "Delete note",
    "menu.newNote": "New note",
    "menu.allNotes": "All notes…",
    "menu.archive": "Archive…",
    "menu.shortcuts": "Keyboard shortcuts",
    "menu.about": "About",
    "about.tagline": "A deck of sticky notes docked to the edge of your screen.",
    "about.version": "Version {version}",
    "about.repository": "Repository",
    "about.openRepo": "Open in your browser",
    "about.pluginId": "Plugin id",
    "about.storage": "Notes live in",
    "about.key": "Encryption key",
    "about.key.keyring": "your login keyring (libsecret)",
    "about.key.file": "a local key file",
    "about.sealed": "Titles and bodies are sealed with ChaCha20-Poly1305 before they are written. Nothing here opens a socket.",
    "about.licence": "Licence",
    "about.licenceValue": "MIT",
    "about.close": "Close",
    "menu.overFullscreen": "Show over full-screen apps",
    "menu.orderHeading": "On the edge, first:",
    "menu.languageHeading": "Language:",
    "menu.order.recent": "Recently edited",
    "menu.order.manual": "The order I added them",
    "menu.order.oldest": "Oldest first",
    "toast.deleted.one": "Note deleted",
    "toast.deleted.other": "{n} notes deleted",
    "toast.undo": "Undo",

    // -- a note ----------------------------------------------------------
    "note.untitled": "Untitled note",
    "note.placeholder": "Write something…",
    "note.find": "Find in note",
    "note.edited": "edited {date}",
    "note.escToClose": "Esc to close",
    "note.action.colour": "Cycle colour · Ctrl + .",
    "note.action.archive": "Archive — keeps the note, off the deck · Ctrl + Shift + A",
    "note.action.delete": "Delete — with ten seconds to undo · Ctrl + Backspace",
    "note.action.deleteArmed": "Press again to delete · Ctrl + Backspace",

    // -- all notes -------------------------------------------------------
    "all.search": "Search all notes",
    "all.count.one": "{n} note",
    "all.count.other": "{n} notes",
    "all.filter.all": "All",
    "all.filter.active": "Active",
    "all.filter.archived": "Archived",
    "all.sort.updated": "Recently edited",
    "all.sort.created": "Recently created",
    "all.sort.title": "Title A–Z",
    "all.sort.deck": "Deck order",
    "all.sortTooltip": "Sorted by: {sort}",
    "all.selected": "{n} selected",
    "all.clear": "Clear",
    "all.selectAll": "Select all {n} · Ctrl + A",
    "all.clearSelection": "Clear the selection",
    "all.state.active": "ACTIVE · IN THE DECK",
    "all.state.activeShort": "ACTIVE",
    "all.state.archived": "ARCHIVED",
    "all.action.putBack": "Put back",
    "all.action.archive": "Archive",
    "all.action.delete": "Delete",
    "all.action.deleteArmed": "Sure?",
    "all.noSelection": "No note selected",
    "all.empty.none": "No notes yet. Reach for the right edge of the screen.",
    "all.empty.noMatch": "Nothing matches that.",
    "all.footer": "Created {created} · Updated {updated} ago",
    "all.privacy.keyring": "Encrypted on this machine · key in your login keyring",
    "all.privacy.file": "Encrypted on this machine · key in a local key file",

    // -- import and export -----------------------------------------------
    "transfer.import": "Import…",
    "transfer.export": "Export…",
    "transfer.exportCount": "Export {n}…",
    "transfer.importTitle": "Import a .stickies archive",
    "transfer.exportTitle.one": "Export {n} note",
    "transfer.exportTitle.other": "Export {n} notes",
    "transfer.importButton": "Import",
    "transfer.cancel": "Cancel",
    "format.markdown": "Markdown",
    "format.markdown.hint": "one .md per note",
    "format.text": "Plain text",
    "format.text.hint": "one .txt per note",
    "format.single": "Single file",
    "format.single.hint": "one document",
    "format.stickies": "Sticky archive",
    "format.stickies.hint": "imports back whole",
    "status.exported.one": "Exported {n} note to {path}",
    "status.exported.other": "Exported {n} notes to {path}",
    "status.exportFailed": "Export failed: {error}",
    "status.imported.one": "Imported {n} note",
    "status.imported.other": "Imported {n} notes",
    "status.importFailed": "Import failed: {error}",
    "status.nothingSelected": "Nothing selected to export",

    // -- cheat sheet -------------------------------------------------------
    "keys.group.anywhere": "Anywhere",
    "keys.group.deck": "On the deck, once Super + Alt + D has opened it",
    "keys.group.note": "In an open note",
    "keys.group.window": "In this window",
    "keys.newNote": "Write a new note",
    "keys.allNotes": "Open All Notes",
    "keys.archive": "Open the archive",
    "keys.toggleDeck": "Fold the deck open, with the keyboard in it",
    "keys.walk": "Walk the notes · the deck scrolls to follow",
    "keys.ends": "First or last note",
    "keys.openCursor": "Open the one under the cursor",
    "keys.foldAway": "Fold the deck away",
    "keys.escNote": "Back to the deck, or the find bar first",
    "keys.find": "Find in note · Return walks the matches",
    "keys.colour": "Cycle its colour",
    "keys.archiveIt": "Archive it",
    "keys.deleteIt": "Delete it — twice, then ten seconds to undo",
    "keys.titleToBody": "From the title to the body",
    "keys.selectAll": "Select everything the filter left",
    "keys.search": "Jump to the search field",
    "keys.undo": "Put back the last delete",
    "keys.listMove": "Move through the list",
    "keys.escWindow": "Close a sheet, then the window",
    "keys.thisList": "This list",
    "keys.footer": "No key at all: reach for the right edge of the screen and the deck fans out.",
    "keys.homeEnd": "Home / End",
    "keys.arrows": "↑ ↓",
    "keys.f1": "F1  or  ?",

    // -- bar widget --------------------------------------------------------
    "bar.tooltip.one": "{n} note in the deck",
    "bar.tooltip.other": "{n} notes in the deck",

    "time.now": "now",
    "time.minutes": "{n}m",
    "time.hours": "{n}h",
    "time.days": "{n}d",
    "time.months": "{n}mo",
    "time.years": "{n}y"
  },

  es: {

    "deck.newNote": "Nota nueva · Super + Alt + N",
    "deck.ghostTab": "NOTA NUEVA",
    "deck.more": "{n} más · clic o rueda sobre el mazo",
    "menu.openNote": "Abrir nota",
    "menu.cycleColour": "Cambiar color",
    "menu.archiveNote": "Archivar nota",
    "menu.deleteNote": "Borrar nota",
    "menu.newNote": "Nota nueva",
    "menu.allNotes": "Todas las notas…",
    "menu.archive": "Archivo…",
    "menu.shortcuts": "Atajos de teclado",
    "menu.about": "Acerca de",
    "about.tagline": "Un mazo de notas adhesivas anclado al borde de tu pantalla.",
    "about.version": "Versión {version}",
    "about.repository": "Repositorio",
    "about.openRepo": "Abrir en el navegador",
    "about.pluginId": "Id del plugin",
    "about.storage": "Las notas viven en",
    "about.key": "Llave de cifrado",
    "about.key.keyring": "tu llavero de sesión (libsecret)",
    "about.key.file": "un archivo local",
    "about.sealed": "Los títulos y cuerpos se sellan con ChaCha20-Poly1305 antes de escribirse. Nada acá abre un socket.",
    "about.licence": "Licencia",
    "about.licenceValue": "MIT",
    "about.close": "Cerrar",
    "menu.overFullscreen": "Mostrar sobre apps en pantalla completa",
    "menu.orderHeading": "En el borde, primero:",
    "menu.languageHeading": "Idioma:",
    "menu.order.recent": "Editadas recientemente",
    "menu.order.manual": "El orden en que las agregué",
    "menu.order.oldest": "Las más viejas primero",
    "toast.deleted.one": "Nota borrada",
    "toast.deleted.other": "{n} notas borradas",
    "toast.undo": "Deshacer",

    "note.untitled": "Nota sin título",
    "note.placeholder": "Escribí algo…",
    "note.find": "Buscar en la nota",
    "note.edited": "editada {date}",
    "note.escToClose": "Esc para cerrar",
    "note.action.colour": "Cambiar color · Ctrl + .",
    "note.action.archive": "Archivar — la guarda, fuera del mazo · Ctrl + Shift + A",
    "note.action.delete": "Borrar — con diez segundos para deshacer · Ctrl + Backspace",
    "note.action.deleteArmed": "Tocá de nuevo para borrar · Ctrl + Backspace",

    "all.search": "Buscar en todas",
    "all.count.one": "{n} nota",
    "all.count.other": "{n} notas",
    "all.filter.all": "Todas",
    "all.filter.active": "Activas",
    "all.filter.archived": "Archivadas",
    "all.sort.updated": "Editadas recientemente",
    "all.sort.created": "Creadas recientemente",
    "all.sort.title": "Título A–Z",
    "all.sort.deck": "Orden del mazo",
    "all.sortTooltip": "Ordenado por: {sort}",
    "all.selected": "{n} seleccionadas",
    "all.clear": "Limpiar",
    "all.selectAll": "Seleccionar las {n} · Ctrl + A",
    "all.clearSelection": "Limpiar la selección",
    "all.state.active": "ACTIVA · EN EL MAZO",
    "all.state.activeShort": "ACTIVA",
    "all.state.archived": "ARCHIVADA",
    "all.action.putBack": "Devolver",
    "all.action.archive": "Archivar",
    "all.action.delete": "Borrar",
    "all.action.deleteArmed": "¿Seguro?",
    "all.noSelection": "Ninguna nota seleccionada",
    "all.empty.none": "Todavía no hay notas. Acercate al borde derecho de la pantalla.",
    "all.empty.noMatch": "No hay nada que coincida.",
    "all.footer": "Creada {created} · Editada hace {updated}",
    "all.privacy.keyring": "Cifradas en esta máquina · llave en tu llavero de sesión",
    "all.privacy.file": "Cifradas en esta máquina · llave en un archivo local",

    "transfer.import": "Importar…",
    "transfer.export": "Exportar…",
    "transfer.exportCount": "Exportar {n}…",
    "transfer.importTitle": "Importar un archivo .stickies",
    "transfer.exportTitle.one": "Exportar {n} nota",
    "transfer.exportTitle.other": "Exportar {n} notas",
    "transfer.importButton": "Importar",
    "transfer.cancel": "Cancelar",
    "format.markdown": "Markdown",
    "format.markdown.hint": "un .md por nota",
    "format.text": "Texto plano",
    "format.text.hint": "un .txt por nota",
    "format.single": "Archivo único",
    "format.single.hint": "un solo documento",
    "format.stickies": "Archivo de notas",
    "format.stickies.hint": "se importa entero",
    "status.exported.one": "Exportada {n} nota a {path}",
    "status.exported.other": "Exportadas {n} notas a {path}",
    "status.exportFailed": "Falló la exportación: {error}",
    "status.imported.one": "Importada {n} nota",
    "status.imported.other": "Importadas {n} notas",
    "status.importFailed": "Falló la importación: {error}",
    "status.nothingSelected": "No hay nada seleccionado para exportar",

    "keys.group.anywhere": "En cualquier lado",
    "keys.group.deck": "En el mazo, una vez abierto con Super + Alt + D",
    "keys.group.note": "En una nota abierta",
    "keys.group.window": "En esta ventana",
    "keys.newNote": "Escribir una nota nueva",
    "keys.allNotes": "Abrir todas las notas",
    "keys.archive": "Abrir el archivo",
    "keys.toggleDeck": "Desplegar el mazo, con el teclado adentro",
    "keys.walk": "Recorrer las notas · el mazo acompaña",
    "keys.ends": "Primera o última nota",
    "keys.openCursor": "Abrir la que está bajo el cursor",
    "keys.foldAway": "Plegar el mazo",
    "keys.escNote": "Volver al mazo, o cerrar la búsqueda primero",
    "keys.find": "Buscar en la nota · Return recorre las coincidencias",
    "keys.colour": "Cambiar su color",
    "keys.archiveIt": "Archivarla",
    "keys.deleteIt": "Borrarla — dos veces, después diez segundos para deshacer",
    "keys.titleToBody": "Del título al cuerpo",
    "keys.selectAll": "Seleccionar todo lo que dejó el filtro",
    "keys.search": "Ir al campo de búsqueda",
    "keys.undo": "Devolver lo último borrado",
    "keys.listMove": "Moverse por la lista",
    "keys.escWindow": "Cerrar una hoja, después la ventana",
    "keys.thisList": "Esta lista",
    "keys.footer": "Sin ninguna tecla: acercate al borde derecho y el mazo se despliega.",
    "keys.homeEnd": "Home / End",
    "keys.arrows": "↑ ↓",
    "keys.f1": "F1  o  ?",

    "bar.tooltip.one": "{n} nota en el mazo",
    "bar.tooltip.other": "{n} notas en el mazo",

    "time.now": "ahora",
    "time.minutes": "{n}m",
    "time.hours": "{n}h",
    "time.days": "{n}d",
    "time.months": "{n}me",
    "time.years": "{n}a"
  }
}

var MONTHS = {
  en: ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
       "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
  es: ["ene", "feb", "mar", "abr", "may", "jun",
       "jul", "ago", "sep", "oct", "nov", "dic"]
}

// "auto" follows the session's LANG; anything else is the user overruling it,
// which matters on a machine whose locale is one language and whose owner is
// another.
function languageFor(setting, envLang) {
  var wanted = String(setting || "auto")
  if (LANGUAGES.indexOf(wanted) !== -1) return wanted
  var base = String(envLang || "").toLowerCase().split(/[._@-]/)[0]
  return LANGUAGES.indexOf(base) !== -1 ? base : "en"
}

function months(lang) {
  return MONTHS[lang] || MONTHS.en
}

// A missing key falls back to English rather than to a blank label, and to the
// key itself if even that is gone -- a visible key name is a bug report, an
// empty button is a mystery.
function t(lang, key, args) {
  var table = STRINGS[lang] || STRINGS.en
  var value = table[key]
  if (value === undefined) value = STRINGS.en[key]
  if (value === undefined) return key
  if (args) {
    for (var name in args)
      value = value.split("{" + name + "}").join(String(args[name]))
  }
  return value
}

// Spanish and English agree on where the plural boundary is, which is the only
// reason two forms per key is enough.
function plural(lang, key, count, args) {
  var merged = { n: count }
  if (args) for (var name in args) merged[name] = args[name]
  return t(lang, key + (count === 1 ? ".one" : ".other"), merged)
}

// The units the relative-time labels use, so "3d" can become "3d" and "1mo"
// can become "1me" without Notes.js knowing what language it is in.
function timeUnits(lang) {
  return {
    now: t(lang, "time.now"),
    minutes: t(lang, "time.minutes"),
    hours: t(lang, "time.hours"),
    days: t(lang, "time.days"),
    months: t(lang, "time.months"),
    years: t(lang, "time.years")
  }
}
