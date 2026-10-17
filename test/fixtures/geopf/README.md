# Géoplateforme geocoding fixtures

Captured with `curl` on 2026-10-17, for **Villefranche-sur-Saône** (INSEE 69264) only (location
privacy, `CLAUDE.md`), sending the app's `User-Agent`. None is trimmed or changed.

| File | Request | Notes |
|---|---|---|
| `reverse_rue_pierre_morin.json` | `/geocodage/reverse?lon=4.71618&lat=45.98718&index=address&type=street&limit=1` (a tap on Rue Pierre Morin) | one `street` feature: `id` = BAN `idVoie` `69264_1460`, `distance` 31 m |
| `reverse_nothing.json` | `/geocodage/reverse?lon=0&lat=0&index=address&type=street&limit=1` (open sea, far from France) | `features: []` |
| `search_rue_pierre.json` | `/geocodage/search?q=rue%20pierre&type=street&citycode=69264&limit=10` | nine streets of the commune, best first |
| `search_none.json` | `/geocodage/search?q=zzzzqx&type=street&citycode=69264&limit=10` | `features: []` |
| `search_too_short.json` | `/geocodage/search?q=ru&…` (HTTP 400) | the service refuses a `q` outside 3–200 characters or not starting with a letter or digit |

Seen when capturing: `content-type: application/json; charset=utf-8`; positions are GeoJSON
`[longitude, latitude]`; a street's point is one point of the street (not the tap's projection
on it), so `distance` is measured to that point; a tap near a commune boundary may answer a
street of the next commune (`citycode` differs); a latitude outside −90…90 answers HTTP 400.
