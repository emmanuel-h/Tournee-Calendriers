# IGN BD TOPO road fixtures (PLAN §5.18)

Captured with `curl` on 2026-11-13 from the Géoplateforme WFS
(`https://data.geopf.fr/wfs/ows`), for **Villefranche-sur-Saône** (INSEE 69264) only (location
privacy, `CLAUDE.md`), sending the app's `User-Agent`. Every request has `SERVICE=WFS`,
`VERSION=2.0.0`, `REQUEST=GetFeature`, `TYPENAMES=BDTOPO_V3:troncon_de_route`,
`OUTPUTFORMAT=application/json`, `SRSNAME=EPSG:4326`, `COUNT=1000` and
`PROPERTYNAME=identifiant_voie_ban_gauche,identifiant_voie_ban_droite,nom_voie_ban_gauche,nom_voie_ban_droite,insee_commune_gauche,insee_commune_droite,nom_collaboratif_gauche,nom_collaboratif_droite,geometrie`.

| File | Request | Notes |
|---|---|---|
| `by_id_rue_nationale.json` | `CQL_FILTER=BBOX(geometrie,45.9800000,4.7000000,46.0100000,4.7300000,'urn:ogc:def:crs:EPSG::4326') AND (identifiant_voie_ban_gauche='69264_1270' OR identifiant_voie_ban_droite='69264_1270')` | untouched: the 26 stretches of Rue Nationale, its BAN id on both sides |
| `by_id_none.json` | the same with `69264_9999`, an id the BAN does not have | untouched: `features: []`, `crs: null` |
| `zone_centre.json` | `BBOX=45.9900,4.7160,45.9925,4.7195,urn:ogc:def:crs:EPSG::4326` (about 200 × 270 m of the centre) | untouched: 38 stretches, 13 BAN streets; « ESP PAUL BERT » named with no BAN id (2 stretches); 3 stretches with neither |
| `zone_too_many.json` | `BBOX=45.9800,4.7000,46.0000,4.7300,urn:ogc:def:crs:EPSG::4326` (about 2.2 × 2.3 km) | `numberMatched` 1531, `numberReturned` 1000; trimmed to its first 2 stretches whose two sides are in 69264 (Rue Mirabeau, Rue Lavoisier), the rest of the document untouched |

Seen when capturing: `content-type: application/json;charset=UTF-8`; coordinates are
`[longitude, latitude, altitude]`; every stretch is a `LineString`; a stretch along a commune
boundary carries a different BAN id, name and INSEE code on each side, and may have a BAN id on
one side only; a stretch without a BAN id still has `nom_collaboratif_*` when it is named (in
capitals, abbreviated: « ESP PAUL BERT »). The `BBOX` parameter takes the latitude first with
the `urn:ogc:def:crs:EPSG::4326` CRS; inside `CQL_FILTER` too.

**A filter on the BAN id alone takes 16 to 20 s** (no index on those columns); within a `BBOX`
of the same filter it takes 0.1 to 0.35 s, even 20 km across. So the line of a street is asked
within its houses' area plus 2 km (`IgnStreetShapes.idSearchMarginMetres`).
