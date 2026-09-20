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

Sample output from the search endpoint, over the real 50-verse Kāñcippurāṇam
excerpt now in `data/texts/kanchippuranam.xml` (source and rights: see that
file's `sourceDesc`):

```json
{
  "query": "காஞ்சி", "language-filter": "all", "count": 1,
  "results": [ { "verse-id": "KP-28", "text-id": "KP", "language": "tam",
                 "reading-text": "பணங்கொள் பாம்பணி கம்பனார் பனிவரை பயந்த ..." } ]
}
```

`data/texts/km-saiva.xml` now carries one real verse (`KM-S-1`, added
2026-09-20): the opening invocation to Gaṇeśa, transcribed by a non-expert
encoder from an 1889 printed edition of the Śaiva Kāñcīmāhātmya digitised by
Heidelberg University Library (DOI `10.11588/diglit.72555`; see that file's
`sourceDesc` and `notesStmt` for the citation, rights note, and specific
transcription caveats). The rest of the file's apparatus machinery is still
demonstration scaffolding. The two files are still not cross-linked via
`@corresp` — `KM-S-1` is a maṅgala invocation, not sthalapuranam narrative, so
no verse-level correspondence to `kanchippuranam.xml` is asserted yet; the
alignment endpoint (`/kanchi/api/verses/{id}/aligned`) still works, it just
returns an empty `aligned` array until narrative chapters are transcribed and
a real correspondence is verified.

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

**One entity has no authority record, and that is modelled explicitly.**
Kanchipuram and Shiva align cleanly to Wikidata and the GND. Kamakshi as a
goddess does not: the available Wikidata item denotes her *temple*. The corpus
records a project-local URI, relates deity to building with `worshipped-at`, and
states the gap in a machine-readable note, rather than asserting `owl:sameAs`
between a goddess and a building. ADR 5 gives the argument.

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
* **IIIF image URLs are placeholders.** The manifest structure is correct and its
  coordinates match the TEI `<zone>`, but no image server is attached.
* **No authentication.** Deployment permissions are set for public read; an
  editorial workflow needs eXist's user and group model configured properly.
* **Grantha is described but not transliterated.** The manuscript description
  records Grantha script, and the Tamil tables include the Grantha consonants
  used for Sanskrit loanwords, but a full Grantha transliterator is not present.

---

## Licence

Code MIT. Encoding, schema and documentation CC BY 4.0.
