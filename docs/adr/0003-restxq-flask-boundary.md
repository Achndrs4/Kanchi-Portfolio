# 3. Where the boundary between eXist and Flask falls

Date: 2026-08-31
Status: Accepted

## Context

The stack contains both eXist-db and a Python service. Since eXist serves HTTP
natively through RESTXQ, an explicit rule is needed for what belongs where.
Without one, the Python layer tends to accrete endpoints that re-query the
corpus, and the two APIs drift apart.

## Decision

**Anything that reads or writes stored TEI is a RESTXQ endpoint. The Python
service handles only work that does not touch the database.**

In practice the Python service does two things:

1. Script conversion between Devanagari, Tamil and Latin transliteration.
2. Ingest-time normalisation and reporting on files that are not yet in the
   database.

## Consequences

The rule is testable: for any proposed endpoint, ask whether it needs to query
the corpus. If it does, it is XQuery.

Transliteration is on the Python side because it is character-level state
machine work. A Brahmic consonant carries an inherent vowel unless a following
vowel sign or virama cancels it, so the transliteration of a codepoint depends on
its successor. XQuery can express this but has no mutable cursor and treats
strings as immutable sequences, so the implementation is both awkward and slow.
Python also gives access to `unicodedata` and, optionally, to mature libraries
such as Aksharamukha.

Ingest normalisation is on the Python side for the simpler reason that the files
are not in eXist yet; there is nothing to run XQuery against.

The cost is a second deployable component. That is accepted because the
alternative — reimplementing Unicode normalisation inside XQuery — would be worse
along every axis.
