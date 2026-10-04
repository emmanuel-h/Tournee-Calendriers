# Phone storage fixtures

Files as the phone storage of M1 writes them (`infrastructure/local_storage/`),
one JSON file per street. `street_v1.json` is written by hand in schema
version 1; the mapper test reads it so a later change of the schema cannot
silently stop reading streets already on a phone. Houses and floors are out of
order on purpose: reading must not depend on the order.

Every place is in Villefranche-sur-Saône (INSEE 69264).
