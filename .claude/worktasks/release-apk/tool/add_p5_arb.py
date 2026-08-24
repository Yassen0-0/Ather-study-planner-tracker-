# -*- coding: utf-8 -*-
# P5-04 exam-eve mode: appends the batch's keys to both ARB files.
#
# Written to disk and run as a file -- never piped through PowerShell, whose
# console encoding mangled Arabic into '?' once already (see fix_p3_arb.py).
# Reads/writes strict UTF-8; refuses to run twice on the same tree.
import io
import json

AR = {
    "@@x_comment_P5": "=== Batch P5: exam eve mode ===",
    "examEveButton": "ليلة الامتحان",
    "examEveTitle": "ليلة الامتحان",
    "examEveBody": "دروس المادة مرتبة حسب أولوية إثباتها الليلة.",
    "examEveTierUnsettled": "غير مُثبت — بلا امتحان",
    "examEveTierWeakest": "الأضعف إتقانًا",
    "examEveTierNearestDue": "الأقرب سقوطًا",
}

EN = {
    "@@x_comment_P5": "=== Batch P5: exam eve mode ===",
    "examEveButton": "Exam eve",
    "examEveTitle": "Exam eve",
    "examEveBody": "The subject's lessons, ordered by what to prove tonight.",
    "examEveTierUnsettled": "Not yet proven -- no exam",
    "examEveTierWeakest": "Weakest first",
    "examEveTierNearestDue": "Closest to falling due",
}

for path, batch in (
    ("lib/core/l10n/app_ar.arb", AR),
    ("lib/core/l10n/app_en.arb", EN),
):
    data = json.loads(io.open(path, encoding="utf-8").read())
    for key in batch:
        assert key not in data, "%s already in %s" % (key, path)
    data.update(batch)
    out = json.dumps(data, ensure_ascii=False, indent=2)
    io.open(path, "w", encoding="utf-8", newline="\n").write(out + "\n")
    print("added %d keys to %s" % (len(batch), path))
