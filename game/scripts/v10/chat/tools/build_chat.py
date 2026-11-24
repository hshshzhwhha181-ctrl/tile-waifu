#!/usr/bin/env python3
"""Compile the heroine-chat DSL (game/data/v10/chat/src/<hero>.chat) into game/data/v10/chat/threads_<hero>.json.

Run from anywhere:  python3 game/scripts/v10/chat/tools/build_chat.py [--check]
--check only parses and reports (exit 1 on errors) without writing. The Godot selftest
(--chat_selftest=1, chat_selftest.gd) validates the produced JSON in depth; this tool catches syntax early.

DSL
  # comment                      (only at line start)
  @thread <id>                   starts a thread
  trigger: daily|first_win|combo_record|rank_up|comeback|birthday|outfit
  level: <n>                     minimal affection level (1..10)
  title: <text>                  list title
  outfit: <item id>              only for trigger outfit
  need: <flag>                   thread needs a flag set by an earlier choice
  repeat: <days>                 repeatable after <days> since done
  :<node>                        starts a node (the first node of a thread is its start)
  h: <text>                      heroine text bubble
  photo: <folder/name> | <caption>   photo bubble (art id under res://assets/), caption optional
  sticker: <sticker id>          heroine sticker
  voice: <sec> | <transcript>    voice note 2–4 s
  > <text> => <node> [+N] [!flag]       player pill (aff bonus N, sets flag)
  > [st:<sticker id>] => <node> [+N] [!flag]   player sends a sticker as the answer
  => <node>                      continue to node
  end                            thread ends here
"""
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
SRC = os.path.join(ROOT, "data", "v10", "chat", "src")
OUT = os.path.join(ROOT, "data", "v10", "chat")
HEROES = ["mc", "rin", "hana", "yue", "nova"]
CHOICE = re.compile(r"^>\s*(.+?)\s*=>\s*([a-z0-9_]+)((?:\s+[+!][\w]+)*)\s*$")


def parse(path, hero):
    threads, errs = [], []
    t = node = None
    for ln, raw in enumerate(open(path, encoding="utf-8"), 1):
        line = raw.rstrip("\n").strip()
        if not line or line.startswith("#"):
            continue
        where = "%s:%d" % (os.path.basename(path), ln)
        if line.startswith("@thread "):
            t = {"id": line[8:].strip(), "hero": hero, "trigger": "daily", "level": 1, "title": "", "start": "", "nodes": {}}
            threads.append(t)
            node = None
            continue
        if t is None:
            errs.append(where + ": text before @thread")
            continue
        if line.startswith(":"):
            name = line[1:].strip()
            if name in t["nodes"]:
                errs.append(where + ": duplicate node " + name)
            node = {"msgs": []}
            t["nodes"][name] = node
            if not t["start"]:
                t["start"] = name
            continue
        if node is None:
            m = re.match(r"^(trigger|level|title|outfit|need|repeat):\s*(.*)$", line)
            if not m:
                errs.append(where + ": bad header " + line)
                continue
            k, v = m.group(1), m.group(2).strip()
            t[k] = int(v) if k in ("level", "repeat") else v
            continue
        if line.startswith("h:"):
            node["msgs"].append({"k": "text", "t": line[2:].strip()})
        elif line.startswith("photo:"):
            img, _, cap = line[6:].partition("|")
            m = {"k": "photo", "img": img.strip()}
            if cap.strip():
                m["t"] = cap.strip()
            node["msgs"].append(m)
        elif line.startswith("sticker:"):
            node["msgs"].append({"k": "sticker", "id": line[8:].strip()})
        elif line.startswith("voice:"):
            sec, _, tr = line[6:].partition("|")
            node["msgs"].append({"k": "voice", "sec": int(sec.strip()), "t": tr.strip()})
        elif line.startswith(">"):
            m = CHOICE.match(line)
            if not m:
                errs.append(where + ": bad choice " + line)
                continue
            text, nxt, mods = m.group(1), m.group(2), m.group(3).split()
            c = {}
            sm = re.match(r"^\[st:([a-z0-9_]+)\]$", text)
            if sm:
                c["sticker"] = sm.group(1)
            else:
                c["t"] = text
            c["next"] = nxt
            for mod in mods:
                if mod.startswith("+"):
                    c["aff"] = int(mod[1:])
                elif mod.startswith("!"):
                    c["set"] = mod[1:]
            node.setdefault("choices", []).append(c)
        elif line.startswith("=>"):
            node["next"] = line[2:].strip()
        elif line == "end":
            node["end"] = True
        else:
            errs.append(where + ": unknown line " + line)
    for t in threads:
        for name, n in t["nodes"].items():
            outs = ("choices" in n) + ("next" in n) + bool(n.get("end"))
            if outs != 1:
                errs.append("%s/%s: node %s needs exactly one of choices / => / end" % (hero, t["id"], name))
            for nxt in [c["next"] for c in n.get("choices", [])] + ([n["next"]] if "next" in n else []):
                if nxt not in t["nodes"]:
                    errs.append("%s/%s: node %s points to missing %s" % (hero, t["id"], name, nxt))
    return threads, errs


def main():
    check = "--check" in sys.argv
    all_errs, total = [], 0
    for h in HEROES:
        p = os.path.join(SRC, h + ".chat")
        if not os.path.exists(p):
            all_errs.append("missing " + p)
            continue
        threads, errs = parse(p, h)
        all_errs += errs
        total += len(threads)
        if not check and not errs:
            with open(os.path.join(OUT, "threads_%s.json" % h), "w", encoding="utf-8") as f:
                json.dump({"v": 1, "hero": h, "threads": threads}, f, ensure_ascii=False, indent=1)
                f.write("\n")
        print("%s: %d threads" % (h, len(threads)))
    for e in all_errs:
        print("ERROR " + e, file=sys.stderr)
    print("total %d threads, %d errors" % (total, len(all_errs)))
    sys.exit(1 if all_errs else 0)


if __name__ == "__main__":
    main()
