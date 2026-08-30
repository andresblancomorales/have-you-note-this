#!/usr/bin/env python3
"""Store behaviour: sealed round-trips, ordering, export and import."""

import importlib.util
import importlib.machinery
import json
import os
import sys
import tempfile
import unittest

BIN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bin")
sys.path.insert(0, BIN)
# The daemon is an extensionless executable, so it needs an explicit loader.
loader = importlib.machinery.SourceFileLoader("store", os.path.join(BIN, "notethis-store"))
spec = importlib.util.spec_from_loader("store", loader)
store_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(store_module)

TEST_KEY = bytes(range(32))


class StoreTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.path = os.path.join(self.dir.name, "notes.db")
        self.store = store_module.Store(self.path, key=TEST_KEY)

    def tearDown(self):
        self.store.db.close()
        self.dir.cleanup()

    def test_create_and_read_back(self):
        note = self.store.create(title="Groceries", body="- apple\n- 4x banana", color="green")
        self.assertEqual(self.store.get(note["id"])["body"], "- apple\n- 4x banana")
        self.assertEqual(note["state"], "active")

    def test_body_is_not_stored_in_the_clear(self):
        self.store.create(title="Office", body="the launch codes")
        with open(self.path, "rb") as handle:
            raw = handle.read()
        for path in (self.path, self.path + "-wal"):
            if os.path.exists(path):
                with open(path, "rb") as handle:
                    raw += handle.read()
        self.assertNotIn(b"launch codes", raw)
        self.assertNotIn(b"Office", raw)

    def test_a_different_key_cannot_read_the_note(self):
        note = self.store.create(title="Office", body="secret")
        other = store_module.Store(self.path, key=bytes([9]) * 32)
        self.assertEqual(other.get(note["id"])["body"], "")

    def test_blob_moved_between_fields_does_not_decrypt(self):
        note = self.store.create(title="title text", body="body text")
        row = self.store.db.execute(
            "SELECT title_enc FROM notes WHERE id = ?", (note["id"],)).fetchone()
        self.store.db.execute("UPDATE notes SET body_enc = ? WHERE id = ?",
                              (row["title_enc"], note["id"]))
        self.assertEqual(self.store.get(note["id"])["body"], "")

    def test_update_touches_the_edited_stamp_only_when_asked(self):
        note = self.store.create(title="a", body="b")
        self.store.db.execute("UPDATE notes SET updated = 1000 WHERE id = ?", (note["id"],))
        archived = self.store.update(note["id"], {"state": "archived", "touch": False})
        self.assertEqual(archived["updated"], 1000)
        self.assertEqual(archived["state"], "archived")
        edited = self.store.update(note["id"], {"body": "c"})
        self.assertGreater(edited["updated"], 1000)

    def test_notes_list_in_position_order(self):
        first = self.store.create(title="one")
        second = self.store.create(title="two")
        self.assertEqual([n["id"] for n in self.store.list_notes()], [first["id"], second["id"]])
        self.store.reorder([second["id"], first["id"]])
        self.assertEqual([n["id"] for n in self.store.list_notes()], [second["id"], first["id"]])

    def test_delete(self):
        note = self.store.create(title="gone")
        self.store.delete(note["id"])
        self.assertIsNone(self.store.get(note["id"]))
        self.assertEqual(self.store.list_notes(), [])

    def test_unknown_colour_falls_back(self):
        self.assertEqual(self.store.create(color="chartreuse")["color"],
                         store_module.DEFAULT_COLOR)

    def test_export_markdown_one_file_per_note(self):
        self.store.create(title="Groceries", body="- apple")
        self.store.create(title="Office", body="- ship it")
        target = os.path.join(self.dir.name, "out")
        written = self.store.export([n["id"] for n in self.store.list_notes()],
                                    "markdown", target)
        self.assertEqual(len(written), 2)
        self.assertTrue(written[0].endswith("groceries.md"))
        self.assertIn("# Groceries", open(written[0]).read())

    def test_export_collides_without_overwriting(self):
        self.store.create(title="Same", body="one")
        self.store.create(title="Same", body="two")
        target = os.path.join(self.dir.name, "out")
        written = self.store.export([n["id"] for n in self.store.list_notes()],
                                    "text", target)
        self.assertEqual(len(set(written)), 2)

    def test_export_single_file_joins_every_note(self):
        self.store.create(title="One", body="1")
        self.store.create(title="Two", body="2")
        target = os.path.join(self.dir.name, "all")
        written = self.store.export([n["id"] for n in self.store.list_notes()],
                                    "single", target)
        text = open(written[0]).read()
        self.assertIn("# One", text)
        self.assertIn("# Two", text)
        self.assertIn("---", text)

    def test_stickies_roundtrip_keeps_colour_state_and_dates(self):
        note = self.store.create(title="Hold", body="keep me", color="purple",
                                 state="archived")
        archive = os.path.join(self.dir.name, "backup")
        written = self.store.export([note["id"]], "stickies", archive)[0]
        self.assertTrue(written.endswith(".stickies"))

        fresh = store_module.Store(os.path.join(self.dir.name, "fresh.db"), key=TEST_KEY)
        self.assertEqual(fresh.import_stickies(written), 1)
        restored = fresh.list_notes()[0]
        self.assertEqual(restored["id"], note["id"])
        self.assertEqual(restored["title"], "Hold")
        self.assertEqual(restored["body"], "keep me")
        self.assertEqual(restored["color"], "purple")
        self.assertEqual(restored["state"], "archived")
        self.assertEqual(restored["created"], note["created"])

    def test_import_into_the_same_store_does_not_collide(self):
        note = self.store.create(title="Hold", body="keep me")
        written = self.store.export([note["id"]], "stickies",
                                    os.path.join(self.dir.name, "backup"))[0]
        self.store.import_stickies(written)
        notes = self.store.list_notes()
        self.assertEqual(len(notes), 2)
        self.assertNotEqual(notes[0]["id"], notes[1]["id"])

    def test_import_accepts_an_archive_from_the_old_name(self):
        path = os.path.join(self.dir.name, "legacy.stickies")
        with open(path, "w") as handle:
            json.dump({"format": store_module.LEGACY_STICKY_FORMAT, "version": 1,
                       "notes": [{"title": "Old", "body": "still mine",
                                  "color": "blue", "state": "archived"}]}, handle)
        self.assertEqual(self.store.import_stickies(path), 1)
        restored = self.store.list_notes()[0]
        self.assertEqual(restored["title"], "Old")
        self.assertEqual(restored["state"], "archived")

    def test_export_writes_the_current_format(self):
        note = self.store.create(title="Now", body="x")
        written = self.store.export([note["id"]], "stickies",
                                    os.path.join(self.dir.name, "archive"))[0]
        with open(written) as handle:
            self.assertEqual(json.load(handle)["format"], store_module.STICKY_FORMAT)

    def test_import_rejects_a_foreign_file(self):
        path = os.path.join(self.dir.name, "not-ours.stickies")
        with open(path, "w") as handle:
            json.dump({"format": "something.else"}, handle)
        with self.assertRaises(ValueError):
            self.store.import_stickies(path)


class LegacyMigrationTest(unittest.TestCase):
    """Notes written when the plugin was called Hold My Notes must survive."""

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.env = {"XDG_DATA_HOME": os.path.join(self.dir.name, "data"),
                    "XDG_CONFIG_HOME": os.path.join(self.dir.name, "config")}
        self.saved = {k: os.environ.get(k) for k in self.env}
        os.environ.update(self.env)

    def tearDown(self):
        for key, value in self.saved.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        self.dir.cleanup()

    def test_data_dir_adopts_the_old_directory(self):
        legacy = os.path.join(self.env["XDG_DATA_HOME"], store_module.LEGACY_APP)
        os.makedirs(legacy)
        with open(os.path.join(legacy, "notes.db"), "w") as handle:
            handle.write("pretend database")

        moved = store_module.data_dir()

        self.assertTrue(moved.endswith(store_module.APP))
        self.assertFalse(os.path.exists(legacy))
        with open(os.path.join(moved, "notes.db")) as handle:
            self.assertEqual(handle.read(), "pretend database")

    def test_data_dir_leaves_an_existing_store_alone(self):
        legacy = os.path.join(self.env["XDG_DATA_HOME"], store_module.LEGACY_APP)
        current = os.path.join(self.env["XDG_DATA_HOME"], store_module.APP)
        os.makedirs(legacy)
        os.makedirs(current)
        with open(os.path.join(legacy, "notes.db"), "w") as handle:
            handle.write("old")
        with open(os.path.join(current, "notes.db"), "w") as handle:
            handle.write("current")

        store_module.data_dir()

        with open(os.path.join(current, "notes.db")) as handle:
            self.assertEqual(handle.read(), "current")
        self.assertTrue(os.path.exists(legacy))

    def test_settings_come_across_once(self):
        old_dir = os.path.join(self.env["XDG_CONFIG_HOME"], store_module.LEGACY_APP)
        os.makedirs(old_dir)
        with open(os.path.join(old_dir, "settings.json"), "w") as handle:
            handle.write('{"deckOrder": "oldest"}')

        self.assertTrue(store_module.migrate_settings())
        new = os.path.join(self.env["XDG_CONFIG_HOME"], store_module.APP, "settings.json")
        with open(new) as handle:
            self.assertEqual(handle.read(), '{"deckOrder": "oldest"}')
        # Idempotent: a second run has nothing left to carry.
        self.assertFalse(store_module.migrate_settings())

    def test_settings_do_not_overwrite_newer_ones(self):
        old_dir = os.path.join(self.env["XDG_CONFIG_HOME"], store_module.LEGACY_APP)
        new_dir = os.path.join(self.env["XDG_CONFIG_HOME"], store_module.APP)
        os.makedirs(old_dir)
        os.makedirs(new_dir)
        with open(os.path.join(old_dir, "settings.json"), "w") as handle:
            handle.write("old")
        with open(os.path.join(new_dir, "settings.json"), "w") as handle:
            handle.write("new")

        self.assertFalse(store_module.migrate_settings())
        with open(os.path.join(new_dir, "settings.json")) as handle:
            self.assertEqual(handle.read(), "new")


class RpcTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.store = store_module.Store(os.path.join(self.dir.name, "notes.db"), key=TEST_KEY)

    def tearDown(self):
        self.store.db.close()
        self.dir.cleanup()

    def test_hello_reports_schema_and_key_storage(self):
        hello = store_module.handle(self.store, "hello", {})
        self.assertEqual(hello["schema"], store_module.SCHEMA_VERSION)
        self.assertIn("yellow", hello["colors"])

    def test_unknown_op_raises(self):
        with self.assertRaises(ValueError):
            store_module.handle(self.store, "explode", {})

    def test_update_through_rpc(self):
        note = store_module.handle(self.store, "create", {"title": "x"})
        updated = store_module.handle(self.store, "update",
                                      {"id": note["id"], "body": "typed"})
        self.assertEqual(updated["body"], "typed")


if __name__ == "__main__":
    unittest.main()
