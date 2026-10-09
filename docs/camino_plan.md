# My Camino plan

Open **My Camino plan** on the home page, create a named itinerary, and add walking days.

- **Add walking day** uses the existing route planner, alternative routes, true flat-ground pace, dates, departure times and planned breaks. Save to add the day to this itinerary. The next day is prefilled with the last destination and following date.
- **Add day without estimates / rest day** records any guide locations and a date without inventing track distances or times. Choose the same start and finish for a rest day. Use **Choose route for estimates** later to calculate using complete available tracks.
- Days remain in the order added. Change their dates to leave rest days. Gaps in destinations and non-increasing dates are flagged, not silently corrected. Editing an earlier day does not move later days or bookings.
- Open **Location and accommodation**, select an albergue or private accommodation and tap **Add to my Camino plan**. Select the night, then record Considering, Booked or Confirmed, an optional reference and notes. Only days ending at that location are offered.
- Use the accommodation's existing booking/contact links to actually book. The app cannot infer booking confirmation from an external website. Saving, replacing or deleting a stay does not make or cancel a booking.
- Edit a day to recalculate its estimates. A changed destination clears that day's stay, while retaining it when the destination stays the same. Saved stay names and notes remain visible if an accommodation disappears from a later guide.

## Storage and estimates

`camino_user_plans.sqlite` is a separate, versioned SQLite database in application support storage. `plans` stores named itineraries and `days` stores ordered days, route choices, estimate snapshots and typed accommodation references. It is never replaced by a bundled guide update. Existing My Walking Day saves remain separate and unchanged.

Times appear in hours and minutes, and arrival estimates include planned breaks. Estimates reflect the route and pace when saved; they do not silently change on guide updates. Unestimated days are excluded from totals and labelled as unavailable. A removed or incomplete route cannot produce a new estimate. Saved snapshots remain readable.

This feature sends no plans, booking references, notes or location history to a server. There is no account or app cloud synchronisation. OS backups may include app data. Users can remove stays, days or entire plans. Uninstalling the app or clearing its data can remove plans; there is no itinerary export/restore feature in this first version. Online booking pages retain their own privacy practices.

## Validation

`test/camino_plan_test.dart` covers SQLite persistence, booking retention/reset, destination matching, incomplete estimates, continuity warnings, deletion and the accommodation selection workflow. Existing walking-day tests cover route calculations, breaks, times and saved day compatibility.

Version 0.2.83: destination pickers follow forward route connections rather than alphabetical order, including days without estimates. Alternative branches appear before their shared destination, without duplicate location entries. Starting-place pickers remain alphabetical.

## Share a PDF (0.2.84)

Use the share icon in My Camino plan or My walking day, or Share day PDF on an itinerary day. The preview includes the saved distance and walking-time estimates, dates, departure and arrival times, planned breaks, and selected accommodation details. Multi-day plans include an overview followed by each day. Missing estimates remain labelled unavailable.

Booking references and notes are included by default. Switch either off to regenerate the preview and shared document without those details. On Android and iOS, Share / save PDF opens the system sharing menu: choose email or another app, select recipients and send it yourself. On Windows the button opens your PDF viewer; save the file and attach it to an email. Printing and saving are also available through the preview toolbar where supported.

PDF generation uses bundled fonts and works offline. The app does not upload the plan or send messages. Sharing hands a temporary PDF to the selected application, whose own storage and privacy practices apply. The PDF is a readable snapshot, not an importable backup or a booking confirmation. A changed guide may make intermediate stop timings unavailable; stored totals are retained.

Version 0.2.90: location pages put navigation, Add to my plan, confirmed local services and accommodation cards first. Descriptions and photos expand under About this place; route neighbours appear at the bottom. Add to my plan selects or creates an itinerary and opens the existing day-without-estimates form with this destination preselected. Review the origin/date and save; choose a route in My Camino plan later for calculated estimates. Accommodation booking and stay-recording remain available through the cards.
