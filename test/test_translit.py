"""
Tests for the transliteration engine.

The expected values are the conventional IAST and ISO 15919 renderings; they are
written out explicitly rather than generated, so that a change in the tables
that happens to be self-consistent still fails the test.
"""

import sys
import unicodedata
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "services" / "flask"))

from translit import (  # noqa: E402
    detect_script,
    devanagari_to_iast,
    normalise,
    tamil_to_iso15919,
)


@pytest.mark.parametrize(
    "deva,iast",
    [
        ("काञ्ची", "kāñcī"),
        ("शिवः", "śivaḥ"),
        ("कामाक्षी", "kāmākṣī"),
        ("तिष्ठति", "tiṣṭhati"),
        ("नगरे", "nagare"),
        ("सर्वदा", "sarvadā"),
        ("तपसा", "tapasā"),
        ("देवी", "devī"),
        # virama at word end must not leave a stray inherent vowel
        ("सिद्धिम्", "siddhim"),
        # consonant cluster with a following vowel sign
        ("काञ्च्यां", "kāñcyāṃ"),
    ],
)
def test_devanagari_to_iast(deva, iast):
    assert devanagari_to_iast(deva) == iast


@pytest.mark.parametrize(
    "tamil,iso",
    [
        ("காஞ்சி", "kāñci"),
        ("சிவன்", "civaṉ"),
        ("காமாட்சி", "kāmāṭci"),
        ("நகரில்", "nakaril"),
        ("தவத்தால்", "tavattāl"),
        ("அம்மை", "ammai"),
        # the four Tamil liquids that ISO 15919 distinguishes and IAST does not
        ("ழ", "ḻa"),
        ("ள", "ḷa"),
        ("ற", "ṟa"),
        ("ன", "ṉa"),
    ],
)
def test_tamil_to_iso15919(tamil, iso):
    assert tamil_to_iso15919(tamil) == iso


@pytest.mark.parametrize(
    "text,script",
    [("மதுரை", "taml"), ("शिव", "deva"), ("Madurai", "latn")],
)
def test_detect_script(text, script):
    assert detect_script(text) == script


def test_inherent_vowel_is_cancelled_by_virama():
    """A bare consonant plus virama must produce no vowel."""
    assert devanagari_to_iast("क्") == "k"
    assert devanagari_to_iast("क") == "ka"


def test_tamil_vowel_signs_decompose_and_are_restored():
    """
    Tamil ொ, ோ and ௌ have canonical decompositions, so text keyed on different
    systems can compare unequal until normalised. This is the concrete reason
    the ingest pipeline normalises everything to NFC.
    """
    composed = "கௌ"
    decomposed = unicodedata.normalize("NFD", composed)
    assert composed != decomposed
    assert normalise(decomposed) == composed
    # and transliteration must agree regardless of input form
    assert tamil_to_iso15919(decomposed) == tamil_to_iso15919(composed)


def test_devanagari_nuqta_is_a_composition_exclusion():
    """
    Not every Indic character recomposes. U+0958 (क़) is on the Unicode
    composition exclusion list, so NFC leaves it decomposed. Code that assumes
    "NFC means precomposed" is wrong, and this test pins the actual behaviour.
    """
    precomposed = "\u0958"
    nfc = unicodedata.normalize("NFC", precomposed)
    assert nfc != precomposed
    assert len(nfc) == 2
    assert unicodedata.is_normalized("NFC", nfc)


def test_unknown_characters_pass_through():
    """Latin text and punctuation must survive unchanged."""
    assert devanagari_to_iast("Madurai, 1889.") == "Madurai, 1889."
