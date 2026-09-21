"""
Indic script transliteration for the Madurai TEI corpus.

Why this lives in Python rather than XQuery
-------------------------------------------
Transliteration is character-level state machine work: the value of a codepoint
depends on what follows it (a consonant carries an inherent vowel unless a
vowel sign or virama cancels it). XQuery can express this, but only awkwardly
and slowly, since it has no mutable cursor and string indexing is O(n). Keeping
it in Python means the logic is testable in isolation and can be reused by the
ingest pipeline, which never touches eXist at all.

The module has no third-party dependencies on purpose. Aksharamukha and
indic-transliteration are both better than this for production use, but a demo
that cannot run without network access to PyPI is a demo that does not get run.
If `aksharamukha` is importable it is preferred automatically; see
`transliterate()`.

Schemes implemented
-------------------
Devanagari -> IAST      (International Alphabet of Sanskrit Transliteration)
Tamil      -> ISO 15919

Note on Tamil: ISO 15919 distinguishes the alveolar/retroflex series that Tamil
orthography marks but IAST does not cover, so the Tamil output uses ISO 15919
rather than IAST. Mixing the two in one corpus is a common source of
irreproducible search results.

@author Ani Chandrashekhar
"""

from __future__ import annotations

import unicodedata
from typing import Dict

# --------------------------------------------------------------------------
# Devanagari
# --------------------------------------------------------------------------

DEVA_CONSONANTS: Dict[str, str] = {
    "क": "k", "ख": "kh", "ग": "g", "घ": "gh", "ङ": "ṅ",
    "च": "c", "छ": "ch", "ज": "j", "झ": "jh", "ञ": "ñ",
    "ट": "ṭ", "ठ": "ṭh", "ड": "ḍ", "ढ": "ḍh", "ण": "ṇ",
    "त": "t", "थ": "th", "द": "d", "ध": "dh", "न": "n",
    "प": "p", "फ": "ph", "ब": "b", "भ": "bh", "म": "m",
    "य": "y", "र": "r", "ल": "l", "व": "v",
    "श": "ś", "ष": "ṣ", "स": "s", "ह": "h",
    "ळ": "ḷ",
}

DEVA_INDEPENDENT_VOWELS: Dict[str, str] = {
    "अ": "a", "आ": "ā", "इ": "i", "ई": "ī", "उ": "u", "ऊ": "ū",
    "ऋ": "ṛ", "ॠ": "ṝ", "ऌ": "ḷ", "ॡ": "ḹ",
    "ए": "e", "ऐ": "ai", "ओ": "o", "औ": "au",
}

DEVA_VOWEL_SIGNS: Dict[str, str] = {
    "\u093e": "ā", "\u093f": "i", "\u0940": "ī", "\u0941": "u", "\u0942": "ū",
    "\u0943": "ṛ", "\u0944": "ṝ", "\u0962": "ḷ", "\u0963": "ḹ",
    "\u0947": "e", "\u0948": "ai", "\u094b": "o", "\u094c": "au",
}

DEVA_VIRAMA = "\u094d"

DEVA_MARKS: Dict[str, str] = {
    "\u0902": "ṃ",   # anusvara
    "\u0903": "ḥ",   # visarga
    "\u0901": "m̐",   # candrabindu
    "\u093d": "'",   # avagraha
}

# --------------------------------------------------------------------------
# Tamil
# --------------------------------------------------------------------------

TAMIL_CONSONANTS: Dict[str, str] = {
    "க": "k", "ங": "ṅ", "ச": "c", "ஞ": "ñ", "ட": "ṭ", "ண": "ṇ",
    "த": "t", "ந": "n", "ப": "p", "ம": "m",
    "ய": "y", "ர": "r", "ல": "l", "வ": "v",
    "ழ": "ḻ", "ள": "ḷ", "ற": "ṟ", "ன": "ṉ",
    # Grantha consonants, used for Sanskrit loanwords in Tamil
    "ஜ": "j", "ஷ": "ṣ", "ஸ": "s", "ஹ": "h", "க்ஷ": "kṣ", "ஶ": "ś",
}

TAMIL_INDEPENDENT_VOWELS: Dict[str, str] = {
    "அ": "a", "ஆ": "ā", "இ": "i", "ஈ": "ī", "உ": "u", "ஊ": "ū",
    "எ": "e", "ஏ": "ē", "ஐ": "ai", "ஒ": "o", "ஓ": "ō", "ஔ": "au",
}

TAMIL_VOWEL_SIGNS: Dict[str, str] = {
    "\u0bbe": "ā", "\u0bbf": "i", "\u0bc0": "ī", "\u0bc1": "u", "\u0bc2": "ū",
    "\u0bc6": "e", "\u0bc7": "ē", "\u0bc8": "ai",
    "\u0bca": "o", "\u0bcb": "ō", "\u0bcc": "au",
}

TAMIL_VIRAMA = "\u0bcd"   # pulli

TAMIL_MARKS: Dict[str, str] = {
    "\u0b83": "ḵ",   # aytam
}


def _transliterate_brahmic(
    text: str,
    consonants: Dict[str, str],
    vowels: Dict[str, str],
    signs: Dict[str, str],
    virama: str,
    marks: Dict[str, str],
    inherent: str = "a",
) -> str:
    """
    Generic Brahmic-script transliterator.

    All Brahmic scripts share one structural rule: a consonant letter implies a
    following inherent vowel, which is cancelled by an explicit vowel sign or by
    the virama. Encoding that rule once and parameterising the tables avoids
    two near-identical functions drifting apart.
    """
    out: list[str] = []
    i = 0
    n = len(text)

    # Longest-match first, so multi-codepoint consonants such as க்ஷ win.
    max_cons = max((len(k) for k in consonants), default=1)

    while i < n:
        ch = text[i]

        # multi-character consonant clusters
        matched = None
        for length in range(min(max_cons, n - i), 0, -1):
            candidate = text[i:i + length]
            if candidate in consonants:
                matched = candidate
                break

        if matched:
            out.append(consonants[matched])
            i += len(matched)
            # Decide the vowel that follows this consonant.
            if i < n and text[i] == virama:
                i += 1                      # virama: no vowel at all
            elif i < n and text[i] in signs:
                out.append(signs[text[i]])
                i += 1
            else:
                out.append(inherent)
            continue

        if ch in vowels:
            out.append(vowels[ch])
            i += 1
            continue

        if ch in marks:
            out.append(marks[ch])
            i += 1
            continue

        if ch in signs:
            # A stray vowel sign with no consonant: keep it visible rather than
            # dropping it silently, so encoding errors surface in the output.
            out.append(signs[ch])
            i += 1
            continue

        if ch == virama:
            i += 1
            continue

        out.append(ch)
        i += 1

    return "".join(out)


def devanagari_to_iast(text: str) -> str:
    """Transliterate Devanagari to IAST."""
    text = unicodedata.normalize("NFC", text)
    return _transliterate_brahmic(
        text, DEVA_CONSONANTS, DEVA_INDEPENDENT_VOWELS,
        DEVA_VOWEL_SIGNS, DEVA_VIRAMA, DEVA_MARKS,
    )


def tamil_to_iso15919(text: str) -> str:
    """Transliterate Tamil to ISO 15919."""
    text = unicodedata.normalize("NFC", text)
    return _transliterate_brahmic(
        text, TAMIL_CONSONANTS, TAMIL_INDEPENDENT_VOWELS,
        TAMIL_VOWEL_SIGNS, TAMIL_VIRAMA, TAMIL_MARKS,
    )


SCHEMES = {
    ("deva", "iast"): devanagari_to_iast,
    ("taml", "iso15919"): tamil_to_iso15919,
}


def detect_script(text: str) -> str:
    """
    Identify the dominant Indic script of a string by codepoint block.

    Returns 'deva', 'taml' or 'latn'. Mixed strings return the script of the
    majority of non-ASCII characters, which is adequate for routing but is
    deliberately not used for anything editorial.
    """
    counts = {"deva": 0, "taml": 0, "latn": 0}
    for ch in text:
        cp = ord(ch)
        if 0x0900 <= cp <= 0x097F:
            counts["deva"] += 1
        elif 0x0B80 <= cp <= 0x0BFF:
            counts["taml"] += 1
        elif ch.isalpha() and cp < 0x0250:
            counts["latn"] += 1
    return max(counts, key=counts.get) if any(counts.values()) else "latn"


def transliterate(text: str, source: str | None = None, target: str | None = None) -> str:
    """
    Transliterate `text`, detecting the source script when not given.

    Prefers the `aksharamukha` package when it is installed, since it handles
    far more scripts and edge cases than the tables above; falls back to the
    built-in implementation otherwise.
    """
    src = source or detect_script(text)
    tgt = target or ("iast" if src == "deva" else "iso15919")

    try:  # pragma: no cover - depends on optional dependency
        from aksharamukha import transliterate as ak  # type: ignore

        mapping = {"deva": "Devanagari", "taml": "Tamil"}
        if src in mapping:
            return ak.process(mapping[src], "IAST" if tgt == "iast" else "ISO", text)
    except ImportError:
        pass

    fn = SCHEMES.get((src, tgt))
    if fn is None:
        raise ValueError(f"unsupported transliteration: {src} -> {tgt}")
    return fn(text)


def normalise(text: str) -> str:
    """
    Normalise Indic text to NFC.

    This matters more than it looks. Tamil vowel signs and Devanagari nuqta
    forms have multiple valid Unicode encodings, and text keyed by different
    editors on different systems will not compare equal unless normalised. Every
    string entering the corpus goes through here.
    """
    return unicodedata.normalize("NFC", text)
