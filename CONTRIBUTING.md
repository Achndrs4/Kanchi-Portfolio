# Contributing

## Before you open a pull request

```bash
bash scripts/bootstrap.sh     # once: fetch pinned tooling into .lib/
bash scripts/build-schema.sh  # if you touched schema/kanchi.odd
bash scripts/validate.sh      # must exit 0
python -m pytest test/ -q     # must pass
```

CI runs the same commands, so a green local run means a green pipeline.

## Rules that are easy to get wrong

**Never edit `schema/kanchi.rng` or `schema/kanchi.sch` by hand.** They are
generated from `schema/kanchi.odd`. CI fails if regenerating them produces a
diff, which is the check that stops the committed schema drifting from its
source.

**Never key Latin transliteration into the corpus.** It is generated. See
[ADR 4](docs/adr/0004-transliteration-and-normalisation.md).

**New endpoints:** if it reads stored TEI it belongs in RESTXQ, not in the Flask
service. See [ADR 3](docs/adr/0003-restxq-flask-boundary.md).

**Negative tests are load-bearing.** `test/invalid-*.xml` must continue to fail
validation. If you relax a constraint, delete the fixture that tested it and say
why in the commit message.

## Commit messages

State what changed and why the change was necessary. "fix schema" is not useful
six months later; "require @wit on rdg: unattributed readings cannot be rendered"
is.

## Recording decisions

Anything that a future maintainer might reasonably want to reverse gets an ADR in
`docs/adr/`. Number sequentially, keep the Context / Decision / Consequences
structure, and be explicit about what the decision costs — an ADR that lists only
benefits is advertising, not documentation.
