# Spike T0.4: map and offline tiles (#4)

Date: 2026-10-04 · Branch `t0.4-map-spike` (throwaway; only this report goes to `main`).
Place used everywhere: Villefranche-sur-Saône centre, Rue Nationale (BAN `69264_1270`).

## Verdict

**Go, with caveats** for `maplibre_gl` + OpenFreeMap + offline regions.

- It builds with no Gradle or manifest changes. It renders OpenFreeMap (liberty and positron) and
  IGN Plan. It draws data-driven GeoJSON lines and dots, and reports taps with coordinates and
  features. An offline region shows the map after an airplane-mode cold start.
- Caveat 1, which T4.1 must design for: **OpenFreeMap tiles are versioned every week.** Once the
  app has been online after a weekly planet update, the stored TileJSON points at the new
  version and the tiles already downloaded can no longer be reached offline. The fix is to
  re-download the region whenever the app is online (see §5). The fix was tested and works.
- Caveat 2: **map labels did not render on the emulator** with any of the 3 styles (SwiftShader
  software GPU). Lines, areas, our layers and the icon boxes do render. This still has to be
  checked on a real phone.

## Versions

| Item | Version |
|---|---|
| `maplibre_gl` (+ `_platform_interface`, `_web`) | **0.27.1** (pinned exactly in `pubspec.yaml`) |
| Native SDK pulled in | `org.maplibre.gl:android-sdk-opengl:13.5.0` (OpenGL renderer, not Vulkan) |
| Flutter / Dart | 3.47.6 / 3.13.5 |
| AGP / Gradle / Kotlin | 9.1.0 / 9.3.1 / 2.4.0, minSdk 26 |
| Emulator | `Medium_Phone_API_36.1`, x86_64, Google SwiftShader GPU |

## What was tested, with evidence

Throwaway screen: `lib/ui/map/map_spike_screen.dart`, opened with a temporary « Spike carte »
button on home (debug builds only). Screenshots are in the session scratchpad
(`…/scratchpad/spike/`) and are not committed.

### 1. Build and render: works

- `flutter build apk --debug` and `--release` passed with **no change** to `android/`. The plugin
  applies KGP itself only when no Kotlin extension exists, so it gets along with AGP 9.
  `flutter analyze` is clean and the existing tests still pass (61), including the architecture test.
- OFM **liberty** (`01-liberty-online.png`), **positron** (`05-positron-online.png`) and **IGN Plan**
  (`06-ign-online.png`) all load. Switching style wipes custom layers, so they are re-added in
  `onStyleLoadedCallback`. The spike changes style by rebuilding the widget with a new key.
- **Labels are missing on the emulator.** No street, place or POI text appears, at z16 or at z12
  (`04-liberty-z12.png`), and road-shield boxes are drawn empty. This happens with all 3 styles,
  even though the glyph PBFs download fine (they are in the offline DB) and logcat shows no
  error. The likely cause is SDF text on the SwiftShader software GPU. **To check on a phone.**

### 2. Drawing from Dart: works

- One GeoJSON source and a `line` layer for the street, in 2 sections. `lineColor` is a `match` on
  the feature's `level` property (`fait` / `enPartie` / `aFaire` / `libre`), using the
  `mapStreet*` tokens of `AppColors`.
- One GeoJSON source and a `circle` layer for 8 real BAN house positions. `circleColor` is a
  `match` on `status`, with a dark stroke.
- « Changer données » calls `setGeoJsonSource` on both sources. The map recolours at once
  (**6 ms** for both calls), see `01-…` → `03-data-changed.png`.
- Colour only for now. The PLAN glyphs (`●` `✗` `↻` `○`) need a `symbol` layer, which runs into
  the same label question as §1.

### 3. Taps: works, with one subtlety

- `onMapClick(point, latLng)` returns screen point and coordinates, e.g. `Tap 45.99079, 4.71860`.
- **Taps on our own interactive layers do not reach `onMapClick`**: `featureTapsTriggersMapClick`
  defaults to false. They go to `controller.onFeatureTapped` with the GeoJSON top-level `id` and
  the layer id, e.g. `Objet touché house-651 (spike-houses-dots) à 45.98948, 4.71874` and
  `section-1 (spike-street-line)`. This is exactly what « tap a street of the tournée » needs.
  Each feature must carry a top-level `id` (the `promoteId` option only applies on the web).
- `queryRenderedFeatures(point, [], null)` returns the base-map features under the finger, e.g.
  3 features including the POI « Petit Casino ». They come back as decoded GeoJSON maps.
- Taps keep working offline.

### 4. Offline region: works

Region: bounds SW 45.98225, 4.70827 to NE 45.99575, 4.72773 (about 1.5 km × 1.5 km), zooms 12–17,
pixel ratio 2.625. Each figure was measured on a freshly cleared app (`pm clear`).

| Style | Resources | Tiles (by zoom) | Bytes (plugin status) | DB file | Duration |
|---|---|---|---|---|---|
| OFM liberty | 301 | **4** (z12 1, z13 1, z14 2) | 6.60 MB | 7.2 MB | 1.0–1.3 s |
| OFM positron | 301 | 4 (same tiles) | 6.60 MB | 7.2 MB | 1.2 s |
| IGN Plan | 581 | 90 (z12 1, z13 1, z14 2, z15 6, z16 16, z17 64) | 2.82 MB | n/a | 15.2 s |

(The emulator sits on a fast wired link; on 4G expect several times longer.)

- **OpenFreeMap tiles stop at z14** (TileJSON `maxzoom: 14`), so z15–17 are overzoomed and cost
  nothing. The 4 tiles weigh only **0.38 MB**. **96 % of the region is glyphs**: 291 font ranges
  × 3 stacks (Noto Sans Regular / Bold / Italic) = 6.36 MB. That is a fixed cost per style, the
  same whatever the area's size. The sprites (@1x + @2x) add 0.16 MB.
- Estimate for a real tournée (3 km × 3 km + 300 m margin): about 10–15 z14 tiles, so roughly
  **8–9 MB** in total. PLAN §7's « ≈ 20–50 MB » is pessimistic.
- **Airplane-mode cold start**: Wi-Fi and data were turned off, the app was force-stopped and
  relaunched. The map shows the region with our layers (`07-offline-coldstart-centre.png`).
  Style, TileJSON, sprites and glyphs all come from the offline DB.
- **Outside the region** (Villefranche-sur-Saône, about 1 km west of the box, z15): **not blank but
  coarse**. MapLibre overzooms the z13 tile of the region, so main roads and water show, with no
  buildings and no small streets (`08-offline-outside.png`). Only beyond the z12 tile (≈ 7 km
  wide here) would it be blank. It degrades gracefully, but don't rely on it.
- The DB lives at `files/mbgl-offline.db` (app-private storage, kept until uninstall).

### 5. Gotcha found: weekly tile versions break offline regions

OpenFreeMap's TileJSON (`https://tiles.openfreemap.org/planet`, `max-age=86400`) points at a
**versioned** template, `…/planet/20260927_080001_pt/{z}/{x}/{y}.pbf`, and a new planet build is
published every week. MapLibre stores tiles keyed by that template. Experiment, done by editing
the DB so the region looked as if it had been downloaded one version earlier
(`20260913_164504_pt`):

1. Offline cold start: the map shows (`10-seeded-offline.png`). The region is self-consistent.
2. The map is used **online** for 12 s. MapLibre revalidates the TileJSON and **overwrites the
   stored copy** with the new template. The region's 4 tiles stay under the old template and are
   now orphaned. Only the 2 tiles viewed online were stored under the new one.
3. Offline cold start again. The viewed spot still shows (`11-…-centre.png`), but at z12 most of
   the map is empty (`12-version-bump-offline-z12.png`).

In the field this means: download on Monday, open the app online on Thursday after the weekly
update, go offline on Saturday, and only the places viewed on Thursday remain.

What was tried:

- **Re-running `downloadOfflineRegion` with the same definition while online: works.** The plugin
  finds the same-area region, deletes it, and creates a new one. All 4 tiles were back under the
  new template in 0.1 s. Caveat: the old region is deleted *before* the new download. Its tiles
  become ambient cache (still on disk, but they can be evicted), so a download cut halfway could
  leave gaps.
- `resumeOfflineRegionDownload(id)` on a region from an earlier process: **fails** with
  `ResumeRegionError: Region is no longer actively tracked`. It only works within the same process.
- A bundled style asset (liberty with the stable `…/planet/latest/{z}/{x}/{y}.pbf` template,
  which OpenFreeMap documents) **displays fine** (`13-pinned-asset-online.png`). But an offline
  region **cannot be downloaded from an `asset://` style**: native logs `Unable to parse
  resourceUrl`, and the download hangs at 0/1 **with no error event**. A pinned style would have
  to be served over https (e.g. Firebase Hosting).

IGN Plan uses an **unversioned** template (`/tms/1.0.0/PLAN.IGN/{z}/{x}/{y}.pbf`), so it does not
have this problem.

### 6. Other gotchas

- **Permissions merged from the native SDK**: `INTERNET`, `ACCESS_NETWORK_STATE`,
  `ACCESS_WIFI_STATE`, **`ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION`**. Nothing to add
  by hand. The location permissions are only *declared* (`geolocator` would declare them too for
  « locate me »). Nothing asks for them at runtime unless `myLocationEnabled` is true, which
  matches PLAN §5.3. Mention them in the Play data-safety form (M5). The plugin also pulls in
  `play-services-location` 21.4.0.
- **APK size**: fat release APK 47.8 MB → **78.8 MB (+31 MB)**. Per ABI, `libmaplibre.so` is
  10.9 MB (arm64-v8a) / 7.9 MB (armeabi-v7a) / 11.2 MB (x86_64), and `classes.dex` grows by
  0.9 MB. Split arm64-v8a release APK: **28.4 MB**, so about **+12 MB** per device download.
  Play's per-ABI delivery from the AAB keeps it at that.
- **Don't use `resetOfflineDatabase()` and then download in the same process.** Once, an IGN
  download made right after a reset finished « 301/301 », linked to the *liberty* resources.
  After a fresh process it was correct (581 resources). Not root-caused. Use
  `deleteOfflineRegion` instead.
- **`DownloadRegionStatus` is not sealed** (`InProgress` / `Success` / `Error`), so a `switch`
  needs a `_` case. `downloadOfflineRegion` returns as soon as the region is created, not when
  it is complete: wait for `Success`. Since the plugin's `Error` shadows `dart:core`'s `Error`,
  keep the import confined to the adapter.
- **Architecture (PLAN §10)**: nothing conflicts. Display types (`MapLibreMapController`,
  `LatLng`, layer properties) stay in `ui/map/`. The offline API (`downloadOfflineRegion`,
  `getListOfRegions`, `getOfflineRegionStatus`, `deleteOfflineRegion`) is made of top-level
  functions with no widget, so it fits behind an `OfflineMapStore` port in
  `infrastructure/maplibre_offline/`. The domain can express what to draw as plain GeoJSON-like
  maps (ids, coordinates, `level` / `status` strings). For the spike, the offline calls sit in
  `ui/map/`, because `ui → infrastructure` is forbidden and there was no port to go through.

## Terms

**OpenFreeMap** (openfreemap.org home page and FAQ, `/tos/` last updated 2026-09-09, GitHub
README):

- Free public instance, « no limits on the number of map views or requests », no registration,
  no API key, no cookies. Commercial use: « Yes ». No SLA. The service « may discontinue it at
  any time without notice ».
- **Attribution required**: « OpenFreeMap © OpenMapTiles Data from OpenStreetMap ». MapLibre adds
  it automatically: it is in the TileJSON (also stored offline) and the ⓘ button shows it. Keep
  that button visible.
- **Offline / bulk**: nothing in the terms deals with tile prefetching or offline caching. The ToS
  forbid « Attempt to collect data from the service in automated ways without permission ». For
  real offline or bulk needs they offer weekly full-planet MBTiles / Btrfs downloads. A
  user-triggered download of a few km² (4–15 tiles plus fonts, once per tournée) looks like
  normal app use, not scraping. Since the wording is broad, **an email to info@openfreemap.org
  describing the use is cheap insurance** before release, and sponsoring is encouraged.
- Tiles change every week. `/planet/latest/{z}/{x}/{y}.pbf` is a documented stable alias (cached
  up to 1 day), and non-existing versions are served as the latest.

**IGN Plan** (cartes.gouv.fr/cgu, formerly geoservices.ign.fr/cgu-licences):

- Data under **Licence Ouverte / Etalab 2.0** (reuse allowed, commercial included, **source
  must be credited**). Public endpoint, no key. TMS vector tiles are limited to **400 req/s per
  IP**. Nothing explicit on offline caching, beyond « ne pas nuire au bon fonctionnement des API ».
- The style and `metadata.json` carry **no attribution string**, so the app must show « © IGN »
  itself when this fallback is used.
- It works as a fallback: the style loads, renders and downloads offline. Tiles go up to z18,
  with denser and more French detail (cadastral-looking buildings). Its region is smaller (2.8 MB)
  but slower to fetch (90 tiles).

## Recommendations

**T3.4 (map on Accueil / Ajouter des rues)**

- `MapLibreMap` in `ui/map/tournee_map.dart`, fed by a view state of plain data: street features
  (id, coordinates, level) and house features (id, coordinates, status). Use one GeoJSON source
  per kind, updated with `setGeoJsonSource`, and colours as `match` expressions built from
  `AppColors`. Re-add sources and layers in `onStyleLoadedCallback`.
- Street taps: `onFeatureTapped` with the street id as the GeoJSON top-level `id`. Taps on empty
  map (Ajouter des rues → reverse geocoding): `onMapClick` coordinates.
- Status glyphs on house dots need a `symbol` layer (or per-status sprite images via
  `addImage`). Validate label rendering on a phone first (see « Needs your attention »).
- Default style: OFM **liberty** (positron looks faded under coloured streets). Leave the ⓘ
  attribution button at its default.

**T4.1 (offline download)**

- `OfflineMapStore` port, with a `maplibre_offline` adapter wrapping `downloadOfflineRegion`,
  `getListOfRegions`, `getOfflineRegionStatus`, `deleteOfflineRegion`. Region = tournée bbox +
  300 m, z12–17. Map `InProgress` / `Success` / `Error` to a sealed domain progress type.
- **Handle the weekly tile version.** Whenever the app is online with a downloaded tournée (at
  start-up and when connectivity returns), re-run the region download silently. It costs only a
  few tiles plus 304 revalidations. To avoid the delete-first window, create the new region with
  slightly different bounds (e.g. +1 m, beyond the plugin's tolerance), then delete the old one
  after `Success`. A sturdier alternative: serve our own copy of the style over https (Firebase
  Hosting) with the stable `/planet/latest/` template and a single font stack, which removes the
  version problem and about 4 MB of glyphs. Decide in T4.1. Add an instrumented test: download,
  airplane mode, cold start, map visible.
- Re-estimate PLAN §7's « ≈ 20–50 MB » as **≈ 10 MB** for OpenFreeMap.
- Keep IGN Plan as a manual fallback style only (credit « © IGN » in the UI). It is not worth
  switching automatically.

## Phone check (2026-10-04)

Run by the user on a real phone (Nokia X30 5G, Android) with the spike build:

- **Street names render** — the missing labels were an emulator (software GPU) artefact only.
- **Offline works:** region downloaded, airplane mode on, app force-closed and cold-started, map
  displayed from the offline region.

