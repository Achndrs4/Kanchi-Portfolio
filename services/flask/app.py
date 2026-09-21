"""
Madurai TEI auxiliary service.

Scope, and why it is narrow
---------------------------
eXist-db publishes the corpus itself through RESTXQ; nothing here proxies that.
This service does the two jobs the XML database is genuinely poor at:

1. Script conversion, which is character-level state machine work (see
   translit.py for the argument).
2. Ingest-time normalisation and reporting over files that are not yet in the
   database, and therefore cannot be queried with XQuery.

Keeping the boundary at "does this need to touch stored TEI?" avoids the common
failure mode where a Python layer slowly reimplements the query API and the two
drift out of sync. If a new endpoint here would need to read the corpus, it
belongs in RESTXQ instead.

Run with:  flask --app app run --port 5000

@author Ani Chandrashekhar
"""

from __future__ import annotations

import unicodedata
import xml.etree.ElementTree as ET
from typing import Any

from flask import Flask, jsonify, request

from translit import (
    detect_script,
    devanagari_to_iast,
    normalise,
    tamil_to_iso15919,
    transliterate,
)

TEI_NS = "http://www.tei-c.org/ns/1.0"
ET.register_namespace("", TEI_NS)

app = Flask(__name__)


@app.get("/health")
def health() -> Any:
    return jsonify({"status": "ok", "service": "madurai-tei-auxiliary", "version": "0.1.0"})


@app.get("/api/transliterate")
def transliterate_get() -> Any:
    """
    Transliterate a string.

    Query parameters:
        text    required
        source  optional: deva | taml (detected when omitted)
        target  optional: iast | iso15919 (chosen by source when omitted)
    """
    text = request.args.get("text", "")
    if not text:
        return jsonify({"error": "parameter 'text' is required"}), 400

    source = request.args.get("source")
    target = request.args.get("target")

    try:
        result = transliterate(text, source, target)
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400

    return jsonify(
        {
            "input": text,
            "detected_script": detect_script(text),
            "source": source or detect_script(text),
            "target": target or ("iast" if detect_script(text) == "deva" else "iso15919"),
            "result": result,
        }
    )


@app.post("/api/transliterate/batch")
def transliterate_batch() -> Any:
    """Transliterate many strings in one call, for pipeline use."""
    payload = request.get_json(silent=True) or {}
    items = payload.get("items")
    if not isinstance(items, list):
        return jsonify({"error": "body must be {\"items\": [...]}"}), 400

    results = []
    for item in items:
        text = item if isinstance(item, str) else str(item)
        try:
            results.append({"input": text, "result": transliterate(text)})
        except ValueError as exc:
            results.append({"input": text, "error": str(exc)})
    return jsonify({"count": len(results), "results": results})


@app.post("/api/normalise")
def normalise_endpoint() -> Any:
    """
    Report and repair Unicode normalisation problems in a submitted string.

    Returns whether the input was already NFC, because for corpus ingest the
    interesting answer is usually "your editor produced NFD" rather than the
    normalised text itself.
    """
    payload = request.get_json(silent=True) or {}
    text = payload.get("text", "")
    if not text:
        return jsonify({"error": "field 'text' is required"}), 400

    nfc = normalise(text)
    return jsonify(
        {
            "already_nfc": unicodedata.is_normalized("NFC", text),
            "input_codepoints": len(text),
            "nfc_codepoints": len(nfc),
            "result": nfc,
        }
    )


@app.post("/api/tei/enrich")
def tei_enrich() -> Any:
    """
    Add generated transliterations to a TEI fragment.

    For every element carrying xml:lang in a supported Indic script, a sibling
    element is added with the transliterated text and a -Latn language tag. The
    generated content is marked so that it is never mistaken for keyed text:
    transliteration is derived data and must be regenerable from the source.
    """
    payload = request.get_json(silent=True) or {}
    xml_text = payload.get("xml", "")
    if not xml_text:
        return jsonify({"error": "field 'xml' is required"}), 400

    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError as exc:
        return jsonify({"error": f"not well-formed XML: {exc}"}), 400

    added = 0
    for elem in list(root.iter()):
        text = "".join(elem.itertext()).strip()
        if not text:
            continue
        script = detect_script(text)
        if script == "deva":
            latin = devanagari_to_iast(text)
            lang = "san-Latn"
        elif script == "taml":
            latin = tamil_to_iso15919(text)
            lang = "tam-Latn"
        else:
            continue
        elem.set("{http://www.w3.org/XML/1998/namespace}lang", elem.get("{http://www.w3.org/XML/1998/namespace}lang", ""))
        elem.set("n-translit", latin)
        elem.set("translit-lang", lang)
        elem.set("translit-source", "generated")
        added += 1

    return jsonify(
        {
            "elements_annotated": added,
            "xml": ET.tostring(root, encoding="unicode"),
        }
    )


if __name__ == "__main__":  # pragma: no cover
    app.run(host="127.0.0.1", port=5000, debug=False)
