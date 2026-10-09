import '../data/camino_repository.dart';
import '../data/models.dart';
import 'camino_plan_store.dart';
import 'safe_links.dart';
import 'walking_day.dart';
import 'walking_day_store.dart';

class PlanPdfContact {
  final String label, value, url;
  const PlanPdfContact(this.label, this.value, this.url);
}

class PlanPdfStop {
  final String name, arrival, departure;
  final int breakMinutes;
  const PlanPdfStop(this.name, this.arrival, this.departure, this.breakMinutes);
}

class PlanPdfDay {
  final ItineraryDay day;
  final List<PlanPdfStop> stops;
  final List<String> breaks;
  final List<PlanPdfContact> contacts;
  final String? address, notice;
  const PlanPdfDay(
    this.day, {
    this.stops = const [],
    this.breaks = const [],
    this.contacts = const [],
    this.address,
    this.notice,
  });
}

class PlanPdfData {
  final String title;
  final List<PlanPdfDay> days;
  const PlanPdfData(this.title, this.days);
  static List<PlanPdfStop> _stops(WalkingDay day, SavedWalkingDay route) {
    final times = day.timetable(route.breaks);
    return [
      for (var i = 0; i < day.places.length; i++)
        PlanPdfStop(
          day.places[i].name,
          walkingDayClock(route.departureMinutes, times.arrivals[i]),
          walkingDayClock(route.departureMinutes, times.departures[i]),
          (times.departures[i] - times.arrivals[i]).inMinutes,
        ),
    ];
  }

  factory PlanPdfData.walkingDay(WalkingDay day, SavedWalkingDay route) =>
      PlanPdfData(day.name, [
        PlanPdfDay(
          ItineraryDay.fromWalkingDay(0, route, day),
          stops: _stops(day, route),
        ),
      ]);

  static Future<PlanPdfData> itinerary(
    String title,
    List<ItineraryDay> days,
    CaminoRepository repository,
  ) async {
    WalkingDayPlanner? planner;
    if (days.any((d) => d.hasEstimate)) {
      // Old snapshots remain exportable when the current guide cannot supply a route.
      try {
        planner = await WalkingDayPlanner.load(repository);
      } catch (_) {
        /* Use snapshots below. */
      }
    }
    final result = <PlanPdfDay>[];
    for (final day in days) {
      List<PlanPdfStop> stops = [];
      final notices = <String>[];
      if (day.hasEstimate) {
        try {
          final current = planner!.calculate(day.route.pathIds, day.route.pace);
          if ((current.metres - day.metres!).abs() > 0.5 ||
              (current.walkingTime.inSeconds - day.seconds!).abs() > 1) {
            throw StateError('Saved estimates differ from the current guide');
          }
          stops = _stops(current, day.route);
        } catch (_) {
          notices.add(
            'Saved distance and walking time retained. Intermediate arrival times are unavailable; edit and save this day to recalculate with current tracks.',
          );
        }
      }
      final locations = await repository.locationsByIds(
        day.route.breaks.keys.toSet(),
      );
      final breaks = [
        for (final entry in day.route.breaks.entries)
          '${locations[entry.key]?.name ?? "Location ${entry.key}"}: ${entry.value} min',
      ];
      Accommodation? accommodation;
      if (day.stay != null) {
        final stay = day.stay!;
        final List<Accommodation> choices = stay.kind == 'albergue'
            ? await repository.albergues(day.endId)
            : await repository.privateAccommodation(day.endId);
        accommodation = choices.where((a) => a.id == stay.id).firstOrNull;
        if (accommodation == null) {
          notices.add(
            'This accommodation is no longer in the current guide. Saved booking details are retained.',
          );
        }
      }
      final contacts = <PlanPdfContact>[];
      if (accommodation != null) {
        for (final phone in accommodation.phoneNumbers) {
          contacts.add(
            PlanPdfContact(
              'Phone',
              phone.international,
              'tel:${phone.international}',
            ),
          );
        }
        final whatsapp = accommodation.whatsAppNumber;
        if (whatsapp != null) {
          contacts.add(
            PlanPdfContact(
              'WhatsApp',
              whatsapp.international,
              'https://wa.me/${whatsapp.international.substring(1)}',
            ),
          );
        }
        final email = SafeLinks.emailAddress(accommodation.email);
        if (email != null) {
          contacts.add(
            PlanPdfContact('Email', email, SafeLinks.emailUrl(email)),
          );
        }
        for (final link in [
          ('Website', accommodation.websiteUrl),
          ('Booking website', accommodation.bookingUrl),
        ]) {
          if (link.$2 != null && SafeLinks.isSafe(link.$2!)) {
            contacts.add(PlanPdfContact(link.$1, link.$1, link.$2!));
          }
        }
      }
      result.add(
        PlanPdfDay(
          day,
          stops: stops,
          breaks: breaks,
          contacts: contacts,
          address: accommodation?.address,
          notice: notices.isEmpty ? null : notices.join('\n'),
        ),
      );
    }
    return PlanPdfData(title, result);
  }
}
