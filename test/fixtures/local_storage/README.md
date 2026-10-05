# Phone storage fixtures

Files as the phone storage of M1 writes them (`infrastructure/local_storage/`),
one JSON file per street, written by hand. The mapper test reads them so a
later change of the schema cannot silently stop reading streets already on a
phone.

- `street_v1.json`: schema version 1, where « repasser » was a flag beside the
  status (houses and doors to do or nobody home with a `comeBack`, a building
  with its own, one in the Corbeille).
- `street_v2.json`: the same street in schema version 2, where « repasser » is
  the status `comeBack`. Both files must read as the same street: that is the
  migration test.

Houses and floors are out of order on purpose: reading must not depend on the
order.

Every place is in Villefranche-sur-Saône (INSEE 69264).
