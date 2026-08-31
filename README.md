# Kanchi TEI

A working demonstration of a digital scholarly edition pipeline for South Indian
temple legends: TEI-XML source with a critical apparatus, a schema generated from
a TEI ODD, an eXist-db application publishing it over RESTXQ, XSLT
transformations to HTML and RDF, and a Python service for Indic script
conversion.

Built as a portfolio piece for research-software work in digital humanities. It
is small on purpose: the aim is to show that every layer of a real editorial
pipeline is present and *tested*, not to simulate a large corpus.

---

## The sample text is synthetic. Please read this first.

The verses in `data/texts/` are **not** transcriptions of the Kāñcīmāhātmya or
the Kāñcippurāṇam. They are invented strings that exercise the encoding model,
and they must not be cited as an edition of anything.

This was a deliberate choice. Producing plausible-looking Sanskrit and Tamil and
presenting it as a critical edition of a living sacred text would be worse than
useless: it would be a fabrication aimed at readers least able to detect it and
most harmed by it. The structure is production-shaped, so authentic
transcriptions can be substituted without touching the schema, the queries or the
transformations. See `docs/encoding-guidelines.md` for how.

The warning is also rendered into the HTML output, because a caveat that only
lives in a README is a caveat nobody reads.

---

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
bash scripts/build-xar.sh        # -> build/kanchi-0.1.0.xar

# 5. Run the auxiliary service
pip install -r services/flask/requirements.txt
python -m flask --app services/flask/app run --port 5000
```

Deploy `build/kanchi-0.1.0.xar` through the eXist Dashboard's package manager, or
with `xmldbc`. The application then answers at
`http://localhost:8080/exist/restxq/kanchi/api`.

---

## The API

```
GET /kanchi/api                          service description
GET /kanchi/api/texts                    all texts, with witness and verse counts
GET /kanchi/api/texts/{id}               TEI source (Accept: application/tei+xml)
GET /kanchi/api/texts/{id}               metadata    (Accept: application/json)
GET /kanchi/api/texts/{id}/apparatus     apparatus criticus
GET /kanchi/api/verses/{id}              one verse: reading text + apparatus
GET /kanchi/api/verses/{id}/aligned      the same verse in the other language
GET /kanchi/api/search?q=…&lang=…        full-text search
GET /kanchi/api/entities                 named entities with authority alignment
```

The same resource is served as TEI or JSON by content negotiation; the TEI
representation is the citable one.

Sample output from the alignment endpoint, showing the Sanskrit verse beside its
Tamil counterpart:

```json
{
  "source":  { "id": "KM-S-1", "language": "san",
               "reading-text": "काञ्च्यां काञ्ची नगरे शुभे शिवः तिष्ठति सर्वदा" },
  "aligned": [ { "id": "KP-1", "language": "tam",
                 "reading-text": "காஞ்சி நகரில் சிவன் என்றும் உறைகின்றார்" } ]
}
```

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
