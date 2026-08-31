# 1. Store the corpus in a native XML database

Date: 2026-08-31
Status: Accepted

## Context

The corpus is TEI-XML: deeply nested, irregular, and queried by structure
("every apparatus entry where witness M1 diverges from the printed edition")
rather than by key. Three storage options were considered: a relational database
with an XML column, a document store holding serialised XML, and a native XML
database.

## Decision

Use eXist-db as the primary store, and query it with XQuery and XPath.

## Consequences

The decisive argument is that XPath is the corpus's natural addressing language.
An edition is *already* a tree, and its citations (chapter, verse, line) are tree
paths. In a relational schema those paths become either a shredded set of tables,
which loses document order and makes reassembly expensive, or an opaque blob,
which makes structural query impossible. Both push the tree-walking logic into
application code, where it is untestable against the data.

eXist additionally provides RESTXQ, so the corpus can be published without a
separate application server, and a Lucene index that can be attached to arbitrary
elements rather than to columns.

Accepted costs:

* The operational knowledge is less common than for PostgreSQL. Mitigated by
  documenting deployment (see `docs/architecture.md`) and pinning the version.
* eXist's own version compatibility is a real constraint. Backups from before
  5.0 are not restorable on later versions, and the forthcoming 7.0 carries
  breaking changes (Java 21, Jetty 12, Lucene 10). We therefore pin 6.4.1 and
  treat the upgrade as a scheduled project, not an incidental one.
* Concurrency behaviour under heavy write load is weaker than a relational
  system. Acceptable here: the corpus is read-mostly, with edits arriving from a
  small editorial team.
