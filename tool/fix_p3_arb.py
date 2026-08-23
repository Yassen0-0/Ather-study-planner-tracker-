# -*- coding: utf-8 -*-
# One-shot repair: the P3 ARB additions were written through a PowerShell pipe
# whose console encoding mangled every non-ASCII character into '?'. Original
# keys are intact; only the eleven new values below were harmed. This script
# restores them verbatim, reading/writing strict UTF-8.
import io
import json

FIXES = {
    "examVerdictWeak": "درس ضعيف — دخل مراجعة الـ30 يوم، ذاكر تاني قبلها.",
    "examVerdictPassed": "عدّيت، مش متقن — امتحان تاني هو اللي يرفعه.",
    "examNeedToCross": "عشان تعدّي الحد: جيب {percentage} في اللي جاي.",
    "comebackLine": "رجعت بعد {days} يوم — {count} درس عبر معاده.",
    "lastHomeworkDated": "آخر واجب ({date})",
    "checklistAllDone": "ذاكرتها كلها — فاضل إنك تثبتها بامتحان.",
    "tasksDayDone": "أنجزت {done} من {total} — يومك خلص.",
    "reviewWaitingHeader": "دروس المراجعة المستنياك: {count}",
    "insightDiscipline": "التزمت {onTime} من {examined} مراجعة في معادها.",
    "purgeCountsLine": "{subjects} مادة · {chapters} باب · {lessons} درس · {exams} امتحان",
    "restoreCopyCounts": "النسخة السحابية: {chapters} باب، {exams} امتحان",
}

PATH = "lib/core/l10n/app_ar.arb"

data = json.loads(io.open(PATH, encoding="utf-8").read())
for key, value in FIXES.items():
    assert key in data, key
    data[key] = value

out = json.dumps(data, ensure_ascii=False, indent=2)
io.open(PATH, "w", encoding="utf-8", newline="\n").write(out + "\n")
print("repaired:", len(FIXES))
