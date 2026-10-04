# BAN `lookup` fixtures

Captured with `curl` from `https://plateforme.adresse.data.gouv.fr/lookup/<id>` on 2026-10-04,
for **Villefranche-sur-Saône** (INSEE 69264) only (location privacy, `CLAUDE.md`).

| File | Source | Trimmed / changed |
|---|---|---|
| `lookup_69264.json` | `/lookup/69264` (the commune, 312 streets) | `voies` cut to 6 entries; all fields of each entry kept |
| `lookup_69264_0246.json` | Petit Chemin de Bordelan | untouched: `217` + `217 bis`, and **`303` twice** (two BAN entries `…_00303` and `…_00303__0` with different positions) |
| `lookup_69264_0682.json` | Rue des Frères Bonnet | `numeros` cut to 185, 200, 200 a–d, 201 (letter suffixes) |
| `lookup_69264_1781_no_numbers.json` | Allée du Square | **derived**: `numeros` emptied, counts set to 0 (no street of the commune is empty today) |
| `lookup_69264_1460_null_position.json` | Rue Pierre Morin | **derived**: `numeros` cut to 32–34, the position of 33 set to `null` (every number of the commune has one today) |
| `lookup_unknown_street.json` | `/lookup/69264_zzzz` (HTTP 404) | untouched |
| `lookup_unknown_commune.json` | `/lookup/69999` (HTTP 404) | untouched |

Seen in the whole commune when capturing: suffixes `bis`, `ter`, `a`–`g` (lowercase); five
streets with a number given twice; every position present, type `Point`, `positionType`
`entrée`; every street of type `voie` (no lieu-dit); `displayBBox` is sometimes a number,
sometimes a list (not read).
