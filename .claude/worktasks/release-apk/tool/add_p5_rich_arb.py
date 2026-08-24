# -*- coding: utf-8 -*-
# P5-06 enriched reminders: appends this batch's keys to both ARB files.
#
# Written to disk and run as a file -- never piped through PowerShell, whose
# console encoding mangled Arabic into '?' once already (see fix_p3_arb.py).
# Reads/writes strict UTF-8; refuses to run twice on the same tree.
import io
import json

AR = [
    (
        "reviewBodyDeclining",
        "آخر امتحان في {lesson} نازل — راجعه قبل ما يوقع.",
    ),
    (
        "reviewBodyWeak",
        "{lesson} لسه ضعيف — ثبّته بامتحان.",
    ),
]

EN = [
    (
        "reviewBodyDeclining",
        "The last exam in {lesson} dropped -- review it before it slips.",
    ),
    (
        "reviewBodyWeak",
        "{lesson} is still weak -- lock it in with an exam.",
    ),
]


def batch(pairs):
    out = {}
    for key, value in pairs:
        out[key] = value
        out["@" + key] = {
            "placeholders": {"lesson": {"type": "String"}},
        }
    return out


for path, pairs in (
    ("lib/core/l10n/app_ar.arb", AR),
    ("lib/core/l10n/app_en.arb", EN),
):
    data = json.loads(io.open(path, encoding="utf-8").read())
    additions = batch(pairs)
    for key in additions:
        assert key not in data, "%s already in %s" % (key, path)
    data.update(additions)
    out = json.dumps(data, ensure_ascii=False, indent=2)
    io.open(path, "w", encoding="utf-8", newline="\n").write(out + "\n")
    print("added %d entries to %s" % (len(additions), path))
