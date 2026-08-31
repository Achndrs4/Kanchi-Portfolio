# 2. Define the schema as a TEI ODD, not as hand-written RELAX NG

Date: 2026-08-31
Status: Accepted

## Context

TEI P5 is permissive by design: it must accommodate every kind of text, so it
allows far more than any single project needs. Validating against unmodified TEI
would accept `<div type="chaper">` and an apparatus entry with no lemma, both of
which break downstream processing.

## Decision

Write `schema/kanchi.odd` as the single source of truth and generate
`kanchi.rng` and `kanchi.sch` from it with the TEI Stylesheets.

## Consequences

One artefact carries the schema, the documentation and the rationale together.
The prose in the ODD explaining *why* `@wit` is required is not a comment that
can drift from the constraint; it is part of the same document, and it appears in
generated documentation.

The division of labour between the two generated schemas is deliberate:

* RELAX NG expresses what a grammar can: which elements nest, which attributes
  are required, which values are permitted.
* Schematron expresses everything else, chiefly cross-references. That every
  pointer in `@wit` resolves to a declared `<witness>` is not a grammatical
  property and cannot be stated in RELAX NG.

Generated artefacts are committed so contributors without Saxon can validate,
and CI fails if regenerating produces a diff, which prevents the committed schema
from silently diverging from the ODD.

Constraints that span documents — chiefly `@corresp` alignment between the
Sanskrit and Tamil texts — are checked in `scripts/validate.sh`, because a
Schematron rule sees one document at a time.
