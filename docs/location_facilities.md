# Location services and repeatable updates

The existing `locations` table gains `hasBarCafe`, `hasPharmacy`, and `hasGroceryStore`. Each is nullable: `1` means supported presence, `0` means explicitly confirmed absence, and `NULL` means unknown. A missing OSM listing never becomes `0`.

Each field also has a `Source` and `CheckedAt` column, for example `hasPharmacySource` and `hasPharmacyCheckedAt`. Only available services appear on location pages, as large icons and short labels. Unknown and unavailable services are hidden, along with an empty section. The date is when the map source was retrieved, not a business visit or telephone confirmation. Long-press a service icon to see its source-check date. Older databases without these columns show no service icons.

`locationFacilities` retains the matched business name, coordinates, straight-line distance from the location pin, OSM URL, tags, retrieval date, and review decision. It contains accepted and deferred/rejected candidates for audit; only accepted candidates contribute to flags. The original guide, accommodation and track tables are not replaced.

## Matching and review

- Bar/café: OSM `amenity=bar`, `cafe`, or `pub`. Restaurants alone are not assumed to be bars.
- Pharmacy: `amenity=pharmacy`. Cosmetic shops are not pharmacies.
- Grocery: `shop=supermarket`, `convenience`, or `grocery`. Bakeries, butchers and souvenir shops alone are not counted.
- Private, explicitly closed or disused businesses are excluded where tagged.
- Candidates are searched within 750 m of each location pin. Distances are straight-line distances, not walking directions or proof of settlement boundaries.
- Named facilities within 300 m, clearly closest to one location, are stronger suggestions. Nearby competing location pins, route landmarks and unnamed/distant results require additional review. Proposals never write flags automatically.
- `Unassigned` and coordinates outside the Camino region are skipped. No absence is inferred from these skipped or empty results.
- Ambiguous candidates can remain deferred. This is intentional: completeness should not come from guessing.

Data may be stale or incomplete even after map matching is reviewed. The database retains an Unknown state; the location page hides unknown services. It does not claim live opening hours or stock availability.

## Repeat the workflow

Python 3, standard library only; run from the app source folder:

```powershell
python tool/location_facilities.py fetch assets/database/camino.sqlite osm_2026_10.json --endpoint https://maps.mail.ru/osm/tools/overpass/api/interpreter
python tool/location_facilities.py propose assets/database/camino.sqlite osm_2026_10.json review_2026_10.json
```

Inspect the names, coordinates, tags and source links. Set **every** candidate's `decision` to `accept`, `defer`, or `reject`, and record the reasoning in `reviewNote`. Then:

```powershell
python tool/location_facilities.py apply assets/database/camino.sqlite review_2026_10.json camino_reviewed.sqlite
```

The tool writes a separate database and refuses to overwrite an existing output. Back up and inspect the result before replacing the bundled database. It preserves manually entered yes/no values whose source does not start `OSM reviewed:`. If a later complete search has no accepted match, it clears only this tool's previous assertion back to Unknown, never to No. The candidate table is refreshed for the reviewed snapshot; keep old JSON reports for history.

Requests are sequential and successful geographic batches are cached beside the snapshot. If a service times out, retry the same command to reuse completed batches, or explicitly select another suitable endpoint for a service outage. Respect HTTP 429 and any Retry-After response: wait before retrying, and do not switch endpoints to evade rate limits. A fresh filename starts a fresh snapshot; do not treat an old cached snapshot as a current check. Do not run this query from pilgrims' phones. This is an editorial maintenance tool; the app reads the resulting data offline and performs no OSM tile downloads.

After replacing the asset, rebuild/install the app. Its existing database fingerprint mechanism installs the new copy while keeping user settings separate.

## Sources

OpenStreetMap contributors, licensed under ODbL: https://www.openstreetmap.org/copyright

Public endpoint information and usage policies: https://wiki.openstreetmap.org/wiki/Overpass_API

Classification follows the OSM tags retained with each candidate. Business operation has not been independently verified solely by finding an OSM object.
