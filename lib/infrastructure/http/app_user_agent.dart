/// What the app sends as `User-Agent` to every public service (BAN,
/// geo.api.gouv.fr). Public services ask callers to say who they are, so a
/// misbehaving client can be identified and contacted rather than blocked.
const appUserAgent =
    'TourneeCalendriers/1.0 '
    '(+https://github.com/emmanuel-h/Tournee-Calendriers)';
