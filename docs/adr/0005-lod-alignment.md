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

**`owl:sameAs` is reserved for genuine identity.** The concrete case that forced
this rule: Kanchipuram has clean external identity — Wikidata Q212332, GND
4259107-7, GeoNames 1268159 — and Shiva likewise (Q11378, GND 118755218). But
**Kamakshi as a goddess has no authority record**; the available Wikidata item
Q2738610 denotes the *Kamakshi Amman Temple*, a building.

Asserting `owl:sameAs` between them would licence a reasoner to conclude that the
goddess has geographic coordinates, an architectural style and an opening time.
The authority file therefore records a project-local URI as authoritative,
relates the deity to the temple with a `worshipped-at` relation, and states the
gap in a machine-readable note. Entities with no equivalent authority get
`skos:relatedMatch`, which records the link without licensing identity inference.

The general rule: **an unrecorded alignment gap is a data-quality problem; a
wrongly asserted one is a correctness problem.** Prefer the former.
