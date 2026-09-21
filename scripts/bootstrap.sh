#!/usr/bin/env bash
# Fetch pinned build tooling into .lib/. Versions are pinned deliberately:
# TEI Stylesheets and Saxon both change generated output between releases, and a
# schema that regenerates differently on a colleague's machine is worse than no
# generated schema at all.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="${ROOT}/.lib"; mkdir -p "${LIB}"

SAXON_VERSION=12.5
RESOLVER_VERSION=5.2.2
JING_VERSION=20241231
TEI_XSL_VERSION=7.61.0

fetch() { [ -f "$2" ] || { echo "  fetching $(basename "$2")"; curl -sL -o "$2" "$1"; }; }

echo "bootstrapping build tooling into .lib/"
fetch "https://repo1.maven.org/maven2/net/sf/saxon/Saxon-HE/${SAXON_VERSION}/Saxon-HE-${SAXON_VERSION}.jar" "${LIB}/saxon.jar"
fetch "https://repo1.maven.org/maven2/org/xmlresolver/xmlresolver/${RESOLVER_VERSION}/xmlresolver-${RESOLVER_VERSION}.jar" "${LIB}/xmlresolver.jar"
fetch "https://repo1.maven.org/maven2/org/xmlresolver/xmlresolver/${RESOLVER_VERSION}/xmlresolver-${RESOLVER_VERSION}-data.jar" "${LIB}/xmlresolver-data.jar"

if [ ! -f "${LIB}/jing.jar" ]; then
  curl -sL -o /tmp/jing.zip "https://github.com/relaxng/jing-trang/releases/download/V${JING_VERSION}/jing-${JING_VERSION}.zip"
  unzip -qo /tmp/jing.zip -d /tmp/jing
  cp "/tmp/jing/jing-${JING_VERSION}/bin/jing.jar" "${LIB}/jing.jar"
fi

if [ ! -d "${LIB}/teixsl" ]; then
  curl -sL -o /tmp/tei-xsl.zip "https://github.com/TEIC/Stylesheets/releases/download/v${TEI_XSL_VERSION}/tei-xsl-${TEI_XSL_VERSION}.zip"
  unzip -qo /tmp/tei-xsl.zip -d "${LIB}/teixsl"
fi

for f in iso_svrl_for_xslt2 iso_schematron_skeleton_for_saxon iso_dsdl_include iso_abstract_expand; do
  fetch "https://raw.githubusercontent.com/Schematron/schematron/master/trunk/schematron/code/${f}.xsl" "${LIB}/${f}.xsl"
done

# Compile the project Schematron into an XSLT once, so validate.sh is fast.
java -cp "${LIB}/saxon.jar:${LIB}/xmlresolver.jar:${LIB}/xmlresolver-data.jar" \
  net.sf.saxon.Transform -s:"${ROOT}/schema/madurai-tei.sch" \
  -xsl:"${LIB}/iso_svrl_for_xslt2.xsl" -o:"${LIB}/madurai-tei-sch.xsl"

echo "done. tooling pinned: Saxon ${SAXON_VERSION}, Jing ${JING_VERSION}, TEI Stylesheets ${TEI_XSL_VERSION}"
