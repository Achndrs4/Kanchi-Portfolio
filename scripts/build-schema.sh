#!/usr/bin/env bash
# Regenerate RELAX NG and Schematron from the ODD. The generated artefacts are
# committed so that contributors without Saxon can still validate, but they must
# never be edited by hand: madurai-tei.odd is the single source of truth.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="${ROOT}/.lib"; ST="${LIB}/teixsl/xml/tei/stylesheet"
CP="${LIB}/saxon.jar:${LIB}/xmlresolver.jar:${LIB}/xmlresolver-data.jar"
TMP="$(mktemp -d)"
java -cp "${CP}" net.sf.saxon.Transform -s:"${ROOT}/schema/madurai-tei.odd" \
     -xsl:"${ST}/odds/odd2odd.xsl" -o:"${TMP}/compiled.odd"
java -cp "${CP}" net.sf.saxon.Transform -s:"${TMP}/compiled.odd" \
     -xsl:"${ST}/odds/odd2relax.xsl" -o:"${ROOT}/schema/madurai-tei.rng"
java -cp "${CP}" net.sf.saxon.Transform -s:"${TMP}/compiled.odd" \
     -xsl:"${ST}/odds/extract-isosch.xsl" -o:"${ROOT}/schema/madurai-tei.sch" lang=en
rm -rf "${TMP}"

# odd2relax.xsl/extract-isosch.xsl each stamp a current-dateTime() comment into
# their output, so two runs against an unchanged ODD are otherwise never
# byte-identical. Normalise it to a fixed placeholder so that regeneration is
# idempotent and CI's "is the committed schema stale" diff check means something.
sed -i -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z/[build-timestamp-elided]/' \
    "${ROOT}/schema/madurai-tei.rng" "${ROOT}/schema/madurai-tei.sch"

echo "regenerated schema/madurai-tei.rng and schema/madurai-tei.sch from schema/madurai-tei.odd"
