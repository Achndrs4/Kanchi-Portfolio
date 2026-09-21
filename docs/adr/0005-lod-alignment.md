# 5. Linked Open Data: CIDOC-CRM, and when not to assert sameAs

Date: 2026-08-31
Status: Accepted

## Context

The project links texts to temple architecture, iconography, ritual and oral
tradition. That is cultural-heritage modelling, and it needs an ontology that can
express objects, places, conceptual works and their relationships.

## Decision

Model the corpus in CIDOC-CRM, publish as RDF, and align entities to Wikidata,
GND and GeoNames — but assert `owl:sameAs` only where the external record denotes
the same kind of thing.

## Consequences

Three modelling choices are worth defending explicitly:

**Texts are `E33_Linguistic_Object`, not documents.** The Kāñcīmāhātmya is a work
transmitted by many carriers. The carriers are separate `E18_Physical_Thing`
resources linked by `P128_carries`. Collapsing work and carrier is the most
common error in text-corpus RDF and makes witness statements incoherent: a
palm-leaf manuscript and an 1889 print cannot both *be* the text.

**Deities are `E28_Conceptual_Object`, not `E21_Person`.** A divine figure in
narrative is not a historical person, and typing it as one invites nonsense
inferences about birth and death dates.

**`owl:sameAs` is reserved for genuine identity.** The corpus's current concrete
case actually shows the failure mode from the *other* direction. Madurai has
clean external identity (Wikidata Q228405, GND 4275927-4, GeoNames 1264521),
Shiva has clean external identity (Q11378, GND 118755218), and — unlike the
Kamakshi case that originally motivated this ADR — **Meenakshi also has her
own clean Wikidata record distinct from her temple** (Q1520192, separate from
the Meenakshi Amman Temple's Q1424358). There is no alignment gap to record
for her.

The gap in this corpus instead concerns **Sundareshvara**, Shiva's name as
worshipped locally at Madurai. He has no separate authority record anywhere —
not because one is missing, but because he is not a separate entity: he *is*
Shiva under a place-specific epithet. The tempting but wrong move is the
mirror image of the original Kamakshi error: instead of wrongly *collapsing*
two distinct things (a goddess and a building) by asserting `sameAs` between
them, it would be wrongly *differentiating* one thing into two — minting a
new `deity-sundareshvara` entity and asserting `sameAs` from it to some
temple-specific Wikidata item, when no such distinct entity exists to align.
The corpus instead treats Sundareshvara as an epithet of the existing
`deity-shiva` entity, recorded as a note on that entity rather than as a
second entity needing its own alignment.

Both errors share one rule: **assert identity only where it's genuine** — not
between things that are actually different (Kamakshi/temple), and not by
inventing a second thing where there's actually one (Shiva/Sundareshvara).
An unrecorded alignment gap is a data-quality problem; a wrongly asserted or
wrongly invented one is a correctness problem. Prefer the former.
