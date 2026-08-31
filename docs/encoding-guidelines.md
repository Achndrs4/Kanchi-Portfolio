# Encoding guidelines

For editors working on the corpus. The schema enforces most of what follows;
where it cannot, the rule is stated here and checked in review.

---

## Replacing the sample corpus

The files in `data/texts/` carry invented verses. To substitute genuine text:

1. Keep the `<teiHeader>` structure. Replace the `<notesStmt>` provenance warning
   with a real `<sourceDesc>` account of the witnesses used.
2. Replace the contents of `<lg>` elements. Keep `@xml:id` stable if anything
   already points at it — `@corresp` alignment, IIIF annotations and any minted
   URIs all resolve through these identifiers.
3. Re-run `bash scripts/validate.sh`. The schema will reject an apparatus entry
   without a lemma, a `@wit` pointer that does not resolve, and a `@corresp` that
   points nowhere in the corpus.
4. Check rights. Nineteenth-century printed editions are generally out of
   copyright; a modern critical edition, a photograph of a manuscript, and a
   modern translation usually are not. Record the position in
   `<publicationStmt>/<availability>`.

Nothing in the schema, the queries or the transformations depends on the sample
content, so no other file needs to change.

---

## Text and script

**Store the Indic script. Never key transliteration.** Latin transliteration is
generated (see ADR 4). If you find yourself typing `kāñcī` into a text file,
something has gone wrong.

**Normalise to NFC on the way in.** `POST /api/normalise` on the Flask service
reports whether a string is already normalised. This is not pedantry: Tamil ொ, ோ
and ௌ have canonical decompositions, so visually identical text keyed on two
machines can compare unequal, which breaks search and de-duplication silently.

Be aware that NFC does not mean "precomposed". Devanagari nuqta characters such
as क़ (U+0958) are Unicode composition exclusions and stay decomposed under NFC.
That is correct behaviour, not a bug.

**Declare the language on the root element.** `@xml:lang` on `<TEI>` is required
by the schema. Use BCP-47 with a script subtag where the script is not implied:
`san-Deva`, `san-Latn`, `tam-Taml`, `tam-Latn`. Do not invent a `@scriptCode`
attribute; TEI has no such attribute on `<language>`.

---

## The apparatus

The corpus uses **parallel segmentation**: variants sit inline inside `<app>`,
inside the running text.

```xml
<app>
  <lem wit="#E1 #M1">काञ्च्यां</lem>
  <rdg wit="#M2">काञ्चीषु</rdg>
</app>
```

Rules, all enforced:

* Every `<app>` must contain a `<lem>`. The reading text is an editorial choice
  and must be made explicitly, not defaulted to the first reading.
* Every `<lem>` and `<rdg>` must carry `@wit`. An unattributed reading cannot be
  rendered or evaluated.
* Every pointer in `@wit` must resolve to a `<witness>` declared in the same
  document's `<listWit>`. Schematron checks this and names the offending pointer.

Use `@type` on `<rdg>` to classify a variant (`orthographic`, `omission`,
`transposition`) when the classification is editorially meaningful. Use
`<witDetail>` for a statement about the *witness* rather than the reading, for
example that a leaf is damaged at that point.

Keep `<app>` inside `<l>`, not spanning line boundaries. A variant crossing lines
needs double-end-point attachment, which this schema does not yet support; raise
it rather than working around it.

---

## Alignment between languages

Sanskrit and Tamil verses that transmit the same episode are linked with
`@corresp`, pointing both ways:

```xml
<lg xml:id="KM-S-1" corresp="#KP-1">   <!-- Sanskrit -->
<lg xml:id="KP-1"  corresp="#KM-S-1">  <!-- Tamil -->
```

Encoding both directions is redundant but deliberate: it makes each file
independently meaningful. The query layer deduplicates with the union operator,
so a verse reachable both ways is returned once.

Alignment is *not* translation. Two verses are aligned when they narrate the same
episode, however freely. If the relationship is looser than that, say so in a
`<note>` rather than stretching `@corresp`.

`scripts/validate.sh` checks that every `@corresp` resolves somewhere in the
corpus. Schematron cannot: it sees one document at a time.

---

## Named entities

Mark people, deities and places with `@ref` into the authority file:

```xml
<placeName ref="authority:place-kanchipuram">காஞ்சி</placeName>
<persName ref="authority:deity-shiva" type="deity">शिवः</persName>
```

The `authority:` prefix is declared in `<listPrefixDef>` in each file's header.

When an entity has no authority record yet, **add one** rather than leaving the
reference off. A record with no external alignment is fine and normal; an
unmarked entity is invisible to every downstream process.

When aligning to an external authority, check that the external record denotes
the same *kind* of thing. Wikidata frequently has an item for a temple but none
for the deity worshipped there. Recording the temple as if it were the deity is a
correctness error, not a shortcut — see ADR 5. Use `<note type="alignment-gap">`
to state what is missing and why.

---

## Manuscript description

Witnesses that are manuscripts get a `<msDesc>` with, at minimum, an
`<msIdentifier>` and a `<scriptDesc>`. Record Grantha explicitly where Sanskrit
is written in Grantha script: it is the norm for Sanskrit manuscripts from the
Tamil country and it affects both transliteration and image processing.

Printed editions are witnesses too. Give them a `<desc>` naming edition, place and
year rather than an `<msDesc>`.
