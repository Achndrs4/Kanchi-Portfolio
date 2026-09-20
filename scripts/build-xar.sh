#!/usr/bin/env bash
# Package the eXist application as an EXPath .xar for deployment.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Read the package version with an XML parser. Grepping for version="..."
# matches the XML declaration first and silently produces "1.0".
VERSION="$(python3 -c "
import xml.etree.ElementTree as ET
print(ET.parse('${ROOT}/exist-app/expath-pkg.xml').getroot().get('version'))")"
BUILD="${ROOT}/build"; STAGE="${BUILD}/stage"
rm -rf "${BUILD}"; mkdir -p "${STAGE}"
cp -r "${ROOT}/exist-app/." "${STAGE}/"
mkdir -p "${STAGE}/data"
cp -r "${ROOT}/data/." "${STAGE}/data/"
mkdir -p "${STAGE}/xslt"
cp "${ROOT}"/xslt/*.xsl "${STAGE}/xslt/"
mkdir -p "${STAGE}/docs"
cp -r "${ROOT}/docs/." "${STAGE}/docs/"
( cd "${STAGE}" && zip -qr "${BUILD}/kanchi-${VERSION}.xar" . )
echo "built ${BUILD}/kanchi-${VERSION}.xar"
