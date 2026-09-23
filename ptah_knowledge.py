#!/usr/bin/env python3
"""
ptah_knowledge.py — sole interface to Ptah's knowledge base (knowledge.db).

No other script or command should open knowledge.db directly. This script is
called by /learn (writes) and /recall (reads), and regenerates INDEX.md as a
side effect of every write. See guides/knowledge-format.md for the schema,
and INDEX.md itself for the human-readable mirror this script maintains.

Requires: Python 3, stdlib only (sqlite3, json, argparse) — no extra installs.

Every subcommand prints JSON to stdout. Invalid category/confidence/relation
values are hard errors (non-zero exit) — never silently coerced to a default.
"""

import argparse
import json
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

KNOWLEDGE_DIR = Path(".claude/ptah/knowledge")
DB_PATH = KNOWLEDGE_DIR / "knowledge.db"
INDEX_PATH = KNOWLEDGE_DIR / "INDEX.md"

CATEGORIES = ["gotcha", "convention", "architecture", "dependency",
              "performance", "security", "tooling"]
CATEGORY_ICONS = {
    "gotcha": "🐛", "convention": "📐", "architecture": "🏗️",
    "dependency": "📦", "performance": "⚡", "security": "🔒", "tooling": "🔧",
}
CONFIDENCE = ["verified", "suspected"]
RELATIONS = ["related", "supersedes", "depends-on", "conflicts-with"]

SCHEMA = """
CREATE TABLE IF NOT EXISTS entries (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    title           TEXT NOT NULL,
    category        TEXT NOT NULL CHECK(category IN
                        ('gotcha','convention','architecture',
                         'dependency','performance','security','tooling')),
    confidence      TEXT NOT NULL CHECK(confidence IN ('verified','suspected')),
    body            TEXT NOT NULL,
    source_command  TEXT,
    added_at        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS tags (
    entry_id  INTEGER NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
    tag       TEXT NOT NULL,
    PRIMARY KEY (entry_id, tag)
);
CREATE INDEX IF NOT EXISTS idx_tags_tag ON tags(tag);

CREATE TABLE IF NOT EXISTS edges (
    from_id   INTEGER NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
    to_id     INTEGER NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
    relation  TEXT NOT NULL DEFAULT 'related' CHECK(relation IN
                  ('related','supersedes','depends-on','conflicts-with')),
    PRIMARY KEY (from_id, to_id, relation)
);
CREATE INDEX IF NOT EXISTS idx_edges_from ON edges(from_id);
CREATE INDEX IF NOT EXISTS idx_edges_to   ON edges(to_id);

CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(
    title, body, content='entries', content_rowid='id'
);

CREATE TRIGGER IF NOT EXISTS entries_ai AFTER INSERT ON entries BEGIN
    INSERT INTO entries_fts(rowid, title, body) VALUES (new.id, new.title, new.body);
END;
CREATE TRIGGER IF NOT EXISTS entries_ad AFTER DELETE ON entries BEGIN
    INSERT INTO entries_fts(entries_fts, rowid, title, body) VALUES('delete', old.id, old.title, old.body);
END;
CREATE TRIGGER IF NOT EXISTS entries_au AFTER UPDATE ON entries BEGIN
    INSERT INTO entries_fts(entries_fts, rowid, title, body) VALUES('delete', old.id, old.title, old.body);
    INSERT INTO entries_fts(rowid, title, body) VALUES (new.id, new.title, new.body);
END;
"""


def connect():
    KNOWLEDGE_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = ON")
    conn.executescript(SCHEMA)
    return conn


def fmt_id(n):
    return str(n)


def parse_id(s):
    return int(str(s).strip())


def fail(message):
    print(json.dumps({"status": "error", "message": message}))
    sys.exit(1)


def cmd_init(args):
    connect().close()
    print(json.dumps({"status": "ok", "db": str(DB_PATH)}))


def cmd_add(args):
    conn = connect()
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")

    parsed_relations = []
    for rel in (args.relates_to or []):
        if ":" in rel:
            target, relation = rel.split(":", 1)
        else:
            target, relation = rel, "related"
        if relation not in RELATIONS:
            fail(f"Unknown relation '{relation}'. Must be one of: {', '.join(RELATIONS)}")
        try:
            target_id = parse_id(target)
        except ValueError:
            fail(f"'{target}' is not a valid entry id.")
        exists = conn.execute("SELECT 1 FROM entries WHERE id = ?", (target_id,)).fetchone()
        if not exists:
            fail(f"Entry {fmt_id(target_id)} does not exist — cannot link to it.")
        parsed_relations.append((target_id, relation))

    cur = conn.execute(
        "INSERT INTO entries (title, category, confidence, body, source_command, added_at) "
        "VALUES (?, ?, ?, ?, ?, ?)",
        (args.title, args.category, args.confidence, args.body, args.source, now),
    )
    entry_id = cur.lastrowid

    tags = [t.strip().lower().replace(" ", "-") for t in (args.tags or "").split(",") if t.strip()]
    for tag in tags:
        conn.execute("INSERT OR IGNORE INTO tags (entry_id, tag) VALUES (?, ?)", (entry_id, tag))

    for target_id, relation in parsed_relations:
        conn.execute(
            "INSERT OR IGNORE INTO edges (from_id, to_id, relation) VALUES (?, ?, ?)",
            (entry_id, target_id, relation),
        )

    conn.commit()
    regenerate_index(conn)
    conn.close()
    print(json.dumps({"status": "ok", "id": fmt_id(entry_id)}))


def cmd_get(args):
    conn = connect()
    try:
        entry_id = parse_id(args.id)
    except ValueError:
        fail(f"'{args.id}' is not a valid entry id.")
    row = conn.execute(
        "SELECT id, title, category, confidence, body, source_command, added_at "
        "FROM entries WHERE id = ?", (entry_id,)
    ).fetchone()
    if not row:
        print(json.dumps({"status": "not_found", "id": fmt_id(entry_id)}))
        conn.close()
        return
    tags = [r[0] for r in conn.execute(
        "SELECT tag FROM tags WHERE entry_id = ? ORDER BY tag", (entry_id,)).fetchall()]
    edges_out = conn.execute(
        "SELECT to_id, relation FROM edges WHERE from_id = ?", (entry_id,)).fetchall()
    edges_in = conn.execute(
        "SELECT from_id, relation FROM edges WHERE to_id = ?", (entry_id,)).fetchall()
    result = {
        "status": "ok",
        "id": fmt_id(row[0]), "title": row[1], "category": row[2], "confidence": row[3],
        "body": row[4], "source_command": row[5], "added_at": row[6], "tags": tags,
        "relates_to": [{"id": fmt_id(t), "relation": r} for t, r in edges_out],
        "related_from": [{"id": fmt_id(f), "relation": r} for f, r in edges_in],
    }
    print(json.dumps(result, indent=2))
    conn.close()


def cmd_search(args):
    conn = connect()
    rows = conn.execute(
        "SELECT e.id, e.title, e.category, e.confidence "
        "FROM entries_fts f JOIN entries e ON e.id = f.rowid "
        "WHERE entries_fts MATCH ? ORDER BY rank", (args.query,)
    ).fetchall()
    print(json.dumps({"status": "ok", "results": [
        {"id": fmt_id(r[0]), "title": r[1], "category": r[2], "confidence": r[3]} for r in rows
    ]}, indent=2))
    conn.close()


def cmd_by_tag(args):
    conn = connect()
    rows = conn.execute(
        "SELECT e.id, e.title, e.category, e.confidence FROM entries e "
        "JOIN tags t ON t.entry_id = e.id WHERE t.tag = ? ORDER BY e.id",
        (args.tag.strip().lower().replace(" ", "-"),)
    ).fetchall()
    print(json.dumps({"status": "ok", "results": [
        {"id": fmt_id(r[0]), "title": r[1], "category": r[2], "confidence": r[3]} for r in rows
    ]}, indent=2))
    conn.close()


def cmd_by_category(args):
    conn = connect()
    rows = conn.execute(
        "SELECT id, title, confidence FROM entries WHERE category = ? ORDER BY id",
        (args.category,)
    ).fetchall()
    print(json.dumps({"status": "ok", "results": [
        {"id": fmt_id(r[0]), "title": r[1], "confidence": r[2]} for r in rows
    ]}, indent=2))
    conn.close()


def cmd_related(args):
    conn = connect()
    try:
        start = parse_id(args.id)
    except ValueError:
        fail(f"'{args.id}' is not a valid entry id.")
    depth = args.depth
    seen = {start}
    frontier = {start}
    result = []
    current_distance = 0
    for _ in range(depth):
        current_distance += 1
        next_frontier = set()
        for node in frontier:
            rows = conn.execute(
                "SELECT to_id AS other, relation FROM edges WHERE from_id = ? "
                "UNION "
                "SELECT from_id AS other, relation FROM edges WHERE to_id = ?",
                (node, node)
            ).fetchall()
            for other, relation in rows:
                if other not in seen:
                    seen.add(other)
                    next_frontier.add(other)
                    title_row = conn.execute(
                        "SELECT title FROM entries WHERE id = ?", (other,)).fetchone()
                    result.append({
                        "id": fmt_id(other),
                        "title": title_row[0] if title_row else None,
                        "relation": relation,
                        "distance": current_distance,
                    })
        frontier = next_frontier
        if not frontier:
            break
    print(json.dumps({"status": "ok", "results": result}, indent=2))
    conn.close()


def regenerate_index(conn):
    lines = [
        "# Knowledge index",
        f"_Regenerated {datetime.now(timezone.utc).isoformat(timespec='seconds')} "
        f"— do not hand-edit, run /learn or /recall to refresh_",
        "",
    ]
    any_entries = False
    for category in CATEGORIES:
        rows = conn.execute(
            "SELECT e.id, e.title, e.confidence, "
            "(SELECT GROUP_CONCAT(tag, ', ') FROM tags WHERE entry_id = e.id) AS tags "
            "FROM entries e WHERE category = ? ORDER BY e.id", (category,)
        ).fetchall()
        if not rows:
            continue
        any_entries = True
        icon = CATEGORY_ICONS.get(category, "")
        lines.append(f"## {icon} {category}")
        lines.append("")
        lines.append("| ID | Title | Tags | Confidence |")
        lines.append("|---|---|---|---|")
        for entry_id, title, confidence, tags in rows:
            out_edges = conn.execute(
                "SELECT to_id FROM edges WHERE from_id = ? ORDER BY to_id", (entry_id,)
            ).fetchall()
            arrow = "".join(f" → {fmt_id(t)}" for (t,) in out_edges)
            lines.append(f"| {fmt_id(entry_id)} | {title}{arrow} | {tags or ''} | {confidence} |")
        lines.append("")
    if not any_entries:
        lines.append("_No entries yet — run `/learn` to capture the first one._")
    INDEX_PATH.write_text("\n".join(lines), encoding="utf-8")


def cmd_regenerate_index(args):
    conn = connect()
    regenerate_index(conn)
    conn.close()
    print(json.dumps({"status": "ok", "index": str(INDEX_PATH)}))


def main():
    parser = argparse.ArgumentParser(description="Sole interface to Ptah's knowledge.db")
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("init")

    p_add = sub.add_parser("add")
    p_add.add_argument("--title", required=True)
    p_add.add_argument("--category", required=True, choices=CATEGORIES)
    p_add.add_argument("--confidence", required=True, choices=CONFIDENCE)
    p_add.add_argument("--body", required=True)
    p_add.add_argument("--tags", default="")
    p_add.add_argument("--source", default=None)
    p_add.add_argument("--relates-to", action="append", default=[],
                        help="entry id or id:relation, repeatable")

    p_get = sub.add_parser("get")
    p_get.add_argument("id")

    p_search = sub.add_parser("search")
    p_search.add_argument("query")

    p_tag = sub.add_parser("by-tag")
    p_tag.add_argument("tag")

    p_cat = sub.add_parser("by-category")
    p_cat.add_argument("category", choices=CATEGORIES)

    p_rel = sub.add_parser("related")
    p_rel.add_argument("id")
    p_rel.add_argument("--depth", type=int, default=1)

    sub.add_parser("regenerate-index")

    args = parser.parse_args()
    dispatch = {
        "init": cmd_init, "add": cmd_add, "get": cmd_get, "search": cmd_search,
        "by-tag": cmd_by_tag, "by-category": cmd_by_category, "related": cmd_related,
        "regenerate-index": cmd_regenerate_index,
    }
    dispatch[args.cmd](args)


if __name__ == "__main__":
    main()
