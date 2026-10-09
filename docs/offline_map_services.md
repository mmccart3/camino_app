# Offline map services

Version 0.2.81 renders service points already stored in the bundled OpenMapTiles `poi` layer. No network requests or additional downloads are needed.

Markers appear at zoom 14 for health services and drinking water, and zoom 15 for food, groceries, toilets and ATMs. Names appear one zoom level later; unnamed points use their service category. Labels avoid overlapping. Zoom in to see more detail.

- Orange: restaurants, cafes, bars, pubs and fast food.
- Green: supermarkets, convenience stores, greengrocers and bakeries.
- Rose: pharmacies, doctors, clinics and hospitals.
- Blue: drinking water.
- Purple: toilets.
- Teal: ATMs.

These are map labels, not tappable accommodation records. OSM accommodation points are deliberately excluded to avoid duplicating the app's curated accommodation data. Services reflect the bundled map snapshot, not live opening hours or verified availability. Existing map coverage is unchanged.

Style: `assets/offline_maps/style.json`. Original base layers are retained; service layers precede place labels. There are no external sprite or glyph dependencies. To refresh service data later, rebuild the offline tiles from updated OSM data.
