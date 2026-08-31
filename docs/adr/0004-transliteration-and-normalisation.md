# 4. Store Indic scripts in NFC and generate transliteration

Date: 2026-08-31
Status: Accepted

## Context

Sanskrit is transmitted in Devanagari and, in the Tamil country, in Grantha.
Tamil is transmitted in Tamil script. Scholarly citation uses Latin
transliteration. A corpus that stores both keyed forms will eventually contain
transliterations that disagree with the text they transliterate.

## Decision

1. The Indic script is the stored form and the only keyed form.
2. Latin transliteration is **generated**, never keyed, and is marked as derived.
3. Everything entering the corpus is normalised to Unicode NFC.
4. Sanskrit uses IAST; Tamil uses ISO 15919.

## Consequences

Generated transliteration cannot drift from its source, because it is
reproducible from it. Where a generated form is stored for indexing, it carries
`translit-source="generated"` so no one mistakes it for editorial content.

Tamil uses ISO 15919 rather than IAST because Tamil orthography distinguishes
four liquids — ழ ḻ, ள ḷ, ற ṟ, ன ṉ — that IAST has no separate signs for. Mixing
the two schemes in one corpus produces search results that depend on which editor
keyed the entry.

On NFC, two facts drove the decision and are pinned by tests:

* Several Tamil vowel signs (ொ, ோ, ௌ) have canonical decompositions. Text keyed
  on different systems can therefore compare unequal despite looking identical,
  which silently breaks both search and `distinct-values`.
* NFC does **not** mean "precomposed". Devanagari nuqta forms such as क़ (U+0958)
  are on the Unicode composition exclusion list, so NFC leaves them decomposed.
  Code asserting that NFC output is always precomposed is wrong; see
  `test/test_translit.py::test_devanagari_nuqta_is_a_composition_exclusion`.
