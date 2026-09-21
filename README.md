# Kanchi TEI

A working demonstration of a digital scholarly edition pipeline for South Indian
temple legends: TEI-XML source with a critical apparatus, a schema generated from
a TEI ODD, an eXist-db application publishing it over RESTXQ, XSLT
transformations to HTML and RDF, and a Python service for Indic script
conversion.

## What is here

| Layer | Technology | Location |
|---|---|---|
| Source encoding | TEI P5, parallel segmentation apparatus | `data/texts/` |
| Authority data | TEI, aligned to Wikidata / GND / GeoNames | `data/authority/` |
| Schema | TEI ODD → RELAX NG + Schematron | `schema/` |
| Database & API | eXist-db 6.4.1, RESTXQ | `exist-app/` |
| Transformations | XSLT 3.0 → HTML5 and RDF/Turtle | `xslt/` |
| Script conversion | Python, Flask | `services/flask/` |
| Images | IIIF Presentation 3.0 | `data/iiif/` |
| Editor support | Oxygen framework, Author-mode CSS | `oxygen/` |
| Automation | Bash, GitHub Actions | `scripts/`, `.github/` |
| Containerised pipeline | Docker Compose, Makefile | `docker/`, `docker-compose.yml`, `Makefile` |

Every component here has been run. The eXist application was deployed to a live
6.4.1 instance and the endpoints exercised over HTTP; the schema was generated
with TEI Stylesheets 7.61.0 and Saxon-HE 12.5; the RDF output was parsed back
with rdflib; the transliteration engine is covered by 27 passing tests.

---

## Quick start

```bash
# 1. Fetch the build tooling (Saxon, Jing, TEI Stylesheets) into .lib/
bash scripts/bootstrap.sh

# 2. Regenerate the schema from the ODD
bash scripts/build-schema.sh

# 3. Validate the corpus: well-formedness, RELAX NG, Schematron, alignment
bash scripts/validate.sh

# 4. Package the eXist application
bash scripts/build-xar.sh        # -> build/kanchi-0.1.6.xar

# 5. Run the auxiliary service
pip install -r services/flask/requirements.txt
python -m flask --app services/flask/app run --port 5000
```

Deploy `build/kanchi-0.1.6.xar` through the eXist Dashboard's package manager, or
with `xmldbc`. The application then answers at
`http://localhost:8080/exist/restxq/kanchi/api`.

### Or, with Docker

The same pipeline, without installing Java/Saxon/xmllint/Python locally. The
`Makefile` wraps `docker compose` and maps 1:1 onto `scripts/*.sh`:

```bash
make bootstrap   # fetch build tooling into .lib/ (containerised)
make schema      # regenerate schema/kanchi.rng + kanchi.sch from the ODD
make validate    # validate the corpus (runs bootstrap + schema first)
make xar         # package build/kanchi-0.1.6.xar
make test        # run the transliteration test suite

make up          # build the .xar, then start eXist-db (localhost:8080) and Flask (localhost:5000)
make down        # stop everything
```

`docker-compose.yml` bind-mounts `build/` onto eXist-db's autodeploy
directory, so once `build/kanchi-0.1.6.xar` exists, starting (or
`make restart-exist`-ing) the `exist` container installs it automatically —
no manual step through the Dashboard. `make help` lists every target.

Container-created files under `.lib/` and `build/` may end up owned by root
on Linux hosts, since the tooling container runs as root by default; `make
clean` removes both directories via the same container so this is not
usually something you need to touch by hand.

---

## The API

```
GET /kanchi/api                          service description
GET /kanchi/api/texts                    all texts, with witness and verse counts
GET /kanchi/api/texts/{id}               TEI source (Accept: application/tei+xml)
GET /kanchi/api/texts/{id}               metadata    (Accept: application/json)
GET /kanchi/api/texts/{id}               reading view, XSLT-rendered HTML (Accept: text/html)
GET /kanchi/api/texts/{id}/apparatus     apparatus criticus
GET /kanchi/api/verses/{id}              one verse: reading text + apparatus
GET /kanchi/api/verses/{id}/aligned      the same verse in the other language
GET /kanchi/api/search?q=…&lang=…        full-text search
GET /kanchi/api/entities                 named entities with authority alignment
```

The same resource is served as TEI, JSON, or HTML by content negotiation; the
TEI representation is the citable one. Opening a text URL in a browser (which
sends `Accept: text/html`) renders `xslt/tei-to-html.xsl` server-side, so the
reading view — including the apparatus criticus — displays inline instead of
downloading raw XML.

Sample output from the search endpoint, over `data/texts/tiruvilaiyadal-puranam.xml`:

```json
{
  "query": "மதுரை", "language-filter": "tam", "count": 44,
  "results": [ { "verse-id": "TVP-1", "text-id": "TVP", "language": "tam",
                 "reading-text": "மதுரை நகரில் அமர்ந்த சொக்கநாதர் ..." } ]
}
```

The corpus is a two-file pair: `data/texts/tiruvilaiyadal-puranam.xml`
(`xml:id="TVP"`, Tamil, 44 chapters) and `data/texts/halasya-mahatmya.xml`
(`xml:id="HM"`, Sanskrit, 44 chapters), replacing the project's earlier
Kanchipuram sample corpus. Each file's `<div type="chapter">` is real: the
padalam/adhyaya numbering and chapter titles were recovered from secondary
sources (Wikipedia and shaivam.org for the Tamil titles; an archive.org OCR
table of contents for the Sanskrit titles) and cross-checked, and every
chapter carries a `@corresp` link to its matched counterpart in the other
file (44 pairs, 88 pointers, all resolving). What is *not* real: the verse
text inside each chapter is synthetic placeholder material, a short generic
couplet reused across chapters to exercise the encoding model, not a
transcription of anything. Both files' `notesStmt` spell out exactly which
padalams/adhyayas were confidently matched and which were left out rather
than guessed at. See `docs/encoding-guidelines.md`, section "Replacing the
sample corpus", for how real verse text should eventually replace this
scaffolding.

---

## Design decisions

The reasoning behind the significant choices is recorded as ADRs:

1. [Native XML database](docs/adr/0001-native-xml-database.md) — why eXist rather
   than PostgreSQL or a document store.
2. [Schema as ODD](docs/adr/0002-tei-customization-via-odd.md) — why the schema is
   generated, and how work is divided between RELAX NG and Schematron.
3. [eXist / Flask boundary](docs/adr/0003-restxq-flask-boundary.md) — the rule for
   what belongs in XQuery and what belongs in Python.
4. [Scripts and normalisation](docs/adr/0004-transliteration-and-normalisation.md)
   — why transliteration is generated, and two Unicode traps in Indic text.
5. [Linked Open Data](docs/adr/0005-lod-alignment.md) — CIDOC-CRM modelling, and
   when *not* to assert `owl:sameAs`.

Two findings worth surfacing here, because they are the parts a reviewer should
push on:

**The schema does real work.** The first validation run rejected this project's
own encoding three times: `variantEncoding` is a child of `encodingDesc`, not
`editorialDecl`; `<language>` has no `@scriptCode` attribute, since script belongs
in the BCP-47 identifier (`san-Deva`, not `san` plus an attribute); and
`<relation>` must sit inside `listRelation`. Those are exactly the errors a
permissive schema lets through into production.

**One entity is deliberately *not* given its own authority record.**
Madurai, Shiva, and Meenakshi all align cleanly to Wikidata and the GND —
Meenakshi has her own record, distinct from her temple. Sundareshvara does
not, because he isn't a separate entity: he's Shiva's name as worshipped
locally at Madurai. The corpus resists the temptation to mint a
`deity-sundareshvara` entity and align *it* to some temple-specific Wikidata
item, and instead records the epithet as a note on the existing `deity-shiva`
entity. ADR 5 gives the argument, including the mirror-image error (Kamakshi)
that originally motivated this rule.

---

## Testing

```bash
bash scripts/validate.sh              # corpus: 4 stages, exits non-zero on failure
python -m pytest test/ -q             # transliteration: 27 tests

# or, containerised:
make validate
make test
```

`test/invalid-*.xml` are deliberately broken fixtures. CI copies each into the
corpus and requires validation to **fail**; a validator that never rejects
anything is indistinguishable from one that does nothing.

---

## Known limitations

Stated plainly, because a portfolio piece that pretends to be finished is less
informative than one that knows its own edges.

* **Sanskrit tokenisation is naive.** Lucene's standard analyser splits on
  whitespace and punctuation, but Sanskrit compounds and sandhi mean word
  boundaries are frequently unmarked. Proper segmentation needs a dedicated
  tokeniser; the index configuration documents this rather than hiding it.
* **The apparatus supports parallel segmentation only.** Double-end-point
  attachment and standoff `<listApp>` are not implemented.
* **No IIIF manifest for the current corpus.** The former Kanchipuram sample
  had a placeholder manifest (`data/iiif/manifest-km-saiva.json`) with correct
  structure and `<zone>`-matched coordinates but no attached image server; it
  was removed along with that corpus rather than left pointing at deleted
  files. No facsimile source was located for the Tiruvilaiyadal Puranam /
  Halasya Mahatmya pair this session, so no replacement manifest exists yet.
* **The new corpus's chapter titles are secondary-source glosses, and its verse
  text is synthetic.** See the `notesStmt/note[@type="provenance-warning"]` in
  `tiruvilaiyadal-puranam.xml` and `halasya-mahatmya.xml` for exactly what was
  and wasn't verified.
* **No authentication.** Deployment permissions are set for public read; an
  editorial workflow needs eXist's user and group model configured properly.
* **Grantha is described but not transliterated.** The manuscript description
  records Grantha script, and the Tamil tables include the Grantha consonants
  used for Sanskrit loanwords, but a full Grantha transliterator is not present.

---

## Licence

Code MIT. Encoding, schema and documentation CC BY 4.0.
