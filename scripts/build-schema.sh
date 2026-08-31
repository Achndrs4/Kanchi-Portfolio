#!/usr/bin/env bash
# Regenerate RELAX NG and Schematron from the ODD. The generated artefacts are
# committed so that contributors without Saxon can still validate, but they must
# never be edited by hand: kanchi.odd is the single source of truth.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="${ROOT}/.lib"; ST="${LIB}/teixsl/xml/tei/stylesheet"
CP="${LIB}/saxon.jar:${LIB}/xmlresolver.jar:${LIB}/xmlresolver-data.jar"
TMP="$(mktemp -d)"
java -cp "${CP}" net.sf.saxon.Transform -s:"${ROOT}/schema/kanchi.odd" \
     -xsl:"${ST}/odds/odd2odd.xsl" -o:"${TMP}/compiled.odd"
java -cp "${CP}" net.sf.saxon.Transform -s:"${TMP}/compiled.odd" \
     -xsl:"${ST}/odds/odd2relax.xsl" -o:"${ROOT}/schema/kanchi.rng"
java -cp "${CP}" net.sf.saxon.Transform -s:"${TMP}/compiled.odd" \
     -xsl:"${ST}/odds/extract-isosch.xsl" -o:"${ROOT}/schema/kanchi.sch" lang=en
rm -rf "${TMP}"
echo "regenerated schema/kanchi.rng and schema/kanchi.sch from schema/kanchi.odd"
