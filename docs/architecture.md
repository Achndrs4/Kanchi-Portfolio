# Architecture

```
                       ┌────────────────────────────┐
    TEI sources ──────▶│  schema/madurai-tei.odd    │
    data/texts/        │  (single source of truth)  │
                       └────────────┬───────────────┘
                                    │ TEI Stylesheets + Saxon
                        ┌───────────┴───────────┐
                        ▼                       ▼
               madurai-tei.rng          madurai-tei.sch
                (grammar: nesting,     (cross-references:
                 required attrs,        @wit resolution,
                 closed value lists)    lemma required)
                        │                       │
                        └───────────┬───────────┘
                                    ▼
                          scripts/validate.sh ──▶ CI gate
                                    │
                                    ▼
   ┌────────────────────────────────────────────────────────┐
   │  eXist-db 6.4.1        /db/apps/madurai-tei              │
   │                                                         │
   │   data/  ──▶ Lucene index (verse-level) + range indexes │
   │   modules/config.xqm   paths, base URI                  │
   │   modules/tei.xqm      queries: apparatus, alignment    │
   │   modules/api.xqm      RESTXQ: 11 endpoints             │
   └───────────────┬─────────────────────────────────────────┘
                   │                        │
                   ▼                        ▼
        xslt/tei-to-html.xsl      xslt/tei-to-rdf.xsl
         reading view + app        CIDOC-CRM Turtle
                                          │
                                          ▼
                              Wikidata / GND / GeoNames

   ┌──────────────────────────────────────────────┐
   │  services/flask   (does NOT read the corpus) │
   │    transliteration: Devanagari→IAST,         │
   │                     Tamil→ISO 15919          │
   │    NFC normalisation and ingest reporting    │
   └──────────────────────────────────────────────┘
```

## Why two servers

See ADR 3. The short version: eXist publishes anything that touches stored TEI,
through RESTXQ. Flask handles character-level and pre-ingest work, which is
awkward in XQuery and, in the ingest case, has no database to query yet. The test
for any new endpoint is whether it needs to read the corpus.

## Deployment

eXist 6.4.1 on Java 21, behind a reverse proxy terminating TLS. The application
deploys as an EXPath `.xar` built by `scripts/build-xar.sh`.

Operational notes learned while building this:

* **Overwriting a module is not enough to reload it.** eXist keeps compiled
  RESTXQ functions in a registry; after replacing `api.xqm` the module must be
  deregistered and registered again, or the old compiled version keeps serving.
  This is the kind of thing that produces a "but I fixed that" incident at 2am.
* **Permissions are not inherited the way a filesystem would suggest.** Both the
  collection and the resources within it need read and execute permission for the
  effective user, or RESTXQ answers 401 with no useful diagnostic.
* **The version pin matters.** eXist backups from before 5.0 cannot be restored
  on 6.x, and 7.0 brings breaking changes (Java 21, Jetty 12, Lucene 10, XML:DB
  API 2.0). Upgrades are scheduled work.

## Indexing

`collection.xconf` attaches the Lucene index to `tei:lg`, the citable unit, so a
hit is directly addressable. Apparatus readings are indexed along with the
reading text, so a search can find a variant that never appears in the printed
text — which is usually the point of having an apparatus at all.

Range indexes on `@xml:id`, `@corresp`, `@ref` and `@wit` matter more than they
look: without them, resolving a verse by identifier is a full collection scan, and
every alignment lookup does it twice.
