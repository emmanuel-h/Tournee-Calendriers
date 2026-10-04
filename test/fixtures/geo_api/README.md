# geo.api.gouv.fr `communes` fixtures

Captured with `curl` from
`https://geo.api.gouv.fr/communes?nom=<q>&fields=nom,code,codesPostaux&boost=population&limit=5`
on 2026-10-04. Location privacy (`CLAUDE.md`): only **Villefranche-sur-Saône** (INSEE 69264) is
kept.

| File | Query | Trimmed / changed |
|---|---|---|
| `communes_villefranche.json` | `nom=Villefranche` | the answer listed 5 communes; only Villefranche-sur-Saône is kept, all its fields (`_score` included, not read) |
| `communes_none.json` | `nom=zzzzqx` | untouched: `[]` |

Seen when capturing: `content-type: application/json; charset=utf-8`; an empty `nom` answers
`[]`; `codesPostaux` is a list (several entries for a commune with several postcodes).
