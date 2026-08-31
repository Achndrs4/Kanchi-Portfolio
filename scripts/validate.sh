#!/usr/bin/env bash
#
# Validate the whole corpus: well-formedness, RELAX NG, Schematron, and the
# cross-document checks that no single-file validator can perform.
#
# Exits non-zero on the first category that fails, so it is usable as a CI gate
# and as a pre-commit hook.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="${ROOT}/.lib"
RNG="${ROOT}/schema/kanchi.rng"
SCH_XSL="${LIB}/kanchi-sch.xsl"

SAXON_CP="${LIB}/saxon.jar:${LIB}/xmlresolver.jar:${LIB}/xmlresolver-data.jar"
JING="${LIB}/jing.jar"

fail=0
say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

say "1/4  Well-formedness"
find "${ROOT}/data" -name '*.xml' -print0 | xargs -0 xmllint --noout
echo "     ok"

say "2/4  RELAX NG (generated from schema/kanchi.odd)"
if [ ! -f "${RNG}" ]; then
  echo "     schema missing; run scripts/build-schema.sh first" >&2
  exit 1
fi
java -jar "${JING}" "${RNG}" $(find "${ROOT}/data" -name '*.xml') || fail=1
[ "${fail}" -eq 0 ] && echo "     ok"

say "3/4  Schematron (project constraints)"
for f in $(find "${ROOT}/data" -name '*.xml'); do
  out="$(mktemp)"
  java -cp "${SAXON_CP}" net.sf.saxon.Transform -s:"$f" -xsl:"${SCH_XSL}" -o:"${out}" 2>/dev/null
  n=$(grep -c 'failed-assert' "${out}" || true)
  if [ "${n}" -gt 0 ]; then
    echo "     FAIL ${f}: ${n} violation(s)"
    grep -o '<svrl:text>[^<]*' "${out}" | sed 's/<svrl:text>/       - /' | head -5
    fail=1
  fi
  rm -f "${out}"
done
[ "${fail}" -eq 0 ] && echo "     ok"

say "4/4  Cross-document alignment"
# @corresp pointers must resolve somewhere in the corpus. Schematron sees one
# document at a time, so this check lives here.
python3 - "$ROOT" <<'PY'
import sys, glob, re, os
root = sys.argv[1]
ids, refs = set(), []
for path in glob.glob(os.path.join(root, "data", "**", "*.xml"), recursive=True):
    s = open(path, encoding="utf-8").read()
    ids.update(re.findall(r'xml:id="([^"]+)"', s))
    for m in re.finditer(r'corresp="([^"]+)"', s):
        for tok in m.group(1).split():
            refs.append((os.path.basename(path), tok.lstrip("#")))
bad = [(f, r) for f, r in refs if r not in ids]
if bad:
    for f, r in bad:
        print(f"     FAIL {f}: @corresp -> #{r} does not resolve")
    sys.exit(1)
print(f"     ok ({len(refs)} alignment pointers, all resolve)")
PY
fail=$(( fail + $? ))

say "Result"
if [ "${fail}" -eq 0 ]; then echo "PASS"; else echo "FAIL"; exit 1; fi
