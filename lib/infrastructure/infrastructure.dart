/// Infrastructure layer: adapters implementing the ports of `domain/` and
/// `application/` (Firestore, geopf / BAN / Overpass over http, MapLibre
/// offline regions, auth, preferences).
///
/// The only layer where Firebase, http and shared_preferences may appear. Its
/// translation code lives in `mappers/` folders, pure and fully tested.
library;
