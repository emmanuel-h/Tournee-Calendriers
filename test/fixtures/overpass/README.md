# Overpass fixtures

Captured with `curl` (POST, form field `data`) on 2026-10-17, for **Villefranche-sur-Saône**
(INSEE 69264) only (location privacy, `CLAUDE.md`), sending the app's `User-Agent`. None is
trimmed or changed. The query is the one `overpassStreetQuery` builds (an accent-, case-,
apostrophe- and hyphen-tolerant regular expression on `name`, in the commune's boundary).

| File | Street asked | Server | Notes |
|---|---|---|---|
| `rue_des_freres_bonnet.json` | `Rue des Freres Bonnet` (the BAN's spelling) | overpass-api.de | three ways named `Rue des Frères Bonnet`: the accent-tolerant match at work |
| `rue_pierre_morin.json` | `Rue Pierre Morin` (exact `name` match) | overpass.kumi.systems (main server down at the time) | three ways; same format |
| `no_way.json` | `Rue Imaginaire du Test` | overpass-api.de | `elements: []` |
| `runtime_error.json` | every highway of the commune with `[maxsize:10000]` | overpass-api.de | HTTP 200 with a `remark` « runtime error: Query ran out of memory … » and no element: what a server-side timeout or memory error looks like |
| `dispatcher_off.html` | any | overpass-api.de (HTTP 504) | the HTML error page sent while the server's database was off |

Seen when capturing: overpass-api.de answered 502 / 504 to most requests for an hour, and its
mirrors 500; a request went through after one to five tries. `content-type: application/json`
(no charset); each way gives `geometry` as `{lat, lon}` objects in the order the road runs.

Matching on `name` in the commune (PLAN §9) finds a way for 284 of the 312 BAN streets of
Villefranche-sur-Saône with the tolerant expression, against 215 with an exact match (BAN names
often lack accents: `Rue du Musee` for OSM's `Rue du Musée`). The rest differ in words
(`Rue Commandant Charcot` / `Rue du Commandant Charcot`) and get no shape.
