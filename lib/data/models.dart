import 'package:latlong2/latlong.dart' show LatLng;
import 'contact_number.dart';

typedef Row = Map<String, Object?>;
int integer(Row r, String key) => (r[key] as num).toInt();
int? optionalInt(Row r, String key) => (r[key] as num?)?.toInt();
double? optionalDouble(Row r, String key) => (r[key] as num?)?.toDouble();
String? text(Row r, String key) => r[key] as String?;
String title(Row r, String key) => text(r, key) ?? 'Unnamed';
LatLng? coordinate(Row r, String latitude, String longitude) {
  final lat = optionalDouble(r, latitude), lon = optionalDouble(r, longitude);
  if (lat == null ||
      lon == null ||
      !lat.isFinite ||
      !lon.isFinite ||
      lat.abs() > 90 ||
      lon.abs() > 180) {
    return null;
  }
  return LatLng(lat, lon);
}

/// Source rows remain available, including fields the MVP does not display.
/// These are projections of existing tables, not a replacement database schema.
abstract class SourceRecord {
  final Row source;
  SourceRecord(Row row) : source = Map.unmodifiable(row);
}

class Stage extends SourceRecord {
  final int id, startLocationId, finishLocationId;
  final int? priorStageId,
      nextStageId,
      alternativePriorStageId,
      alternativeNextStageId;
  final double? distanceMeters, timeMinutes;
  final String name;
  final String? mapUrl, elevationChartUrl;
  Stage.fromRow(super.r)
    : id = integer(r, 'ID'),
      name = title(r, 'stageName'),
      startLocationId = integer(r, 'stageStartLocationID'),
      finishLocationId = integer(r, 'stageFinishLocationID'),
      priorStageId = optionalInt(r, 'priorStage'),
      nextStageId = optionalInt(r, 'nextStage'),
      alternativePriorStageId = optionalInt(r, 'altPriorStage'),
      alternativeNextStageId = optionalInt(r, 'altNextStage'),
      distanceMeters = optionalDouble(r, 'stageDistanceInMetres'),
      timeMinutes = optionalDouble(r, 'stageTimeInMinutes'),
      mapUrl = text(r, 'stageMap1920URL'),
      elevationChartUrl = text(r, 'stageElevationChartURL');
}

class Location extends SourceRecord {
  bool? facility(String column) => switch (source[column]) {
    1 => true,
    0 => false,
    _ => null,
  };
  bool? get hasBarCafe => facility('hasBarCafe');
  bool? get hasPharmacy => facility('hasPharmacy');
  bool? get hasGroceryStore => facility('hasGroceryStore');

  final int id;
  final int? priorLocationId,
      nextLocationId,
      alternativePriorLocationId,
      alternativeNextLocationId;
  final String name;
  final List<String> imageUrls;
  final LatLng? position;
  String? get imageUrl => imageUrls.firstOrNull;
  Location.fromRow(super.r)
    : id = integer(r, 'ID'),
      name = title(r, 'locationName'),
      priorLocationId = optionalInt(r, 'priorLoc'),
      nextLocationId = optionalInt(r, 'nextLoc'),
      alternativePriorLocationId = optionalInt(r, 'altPriorLoc'),
      alternativeNextLocationId = optionalInt(r, 'altNextLoc'),
      imageUrls = List.unmodifiable([
        for (var i = 1; i <= 4; i++)
          if (text(r, 'locationPic${i}URL') != null)
            text(r, 'locationPic${i}URL')!,
      ]),
      position = coordinate(r, 'latitude', 'longitude');
}

class Paragraph extends SourceRecord {
  final int id;
  final int? locationId;
  final String body;
  final String? type, websiteUrl;
  Paragraph.fromRow(super.r)
    : id = integer(r, 'ID'),
      locationId = optionalInt(r, 'locationID'),
      body = text(r, 'paragraphText') ?? '',
      type = text(r, 'paragraphType'),
      websiteUrl = text(r, 'paragraphWebsiteURL');
}

abstract class Accommodation extends SourceRecord {
  List<ContactNumber> get phoneNumbers {
    final unique = <String, ContactNumber>{};
    for (final slot in [1, 2]) {
      final number = ContactNumber.phone(
        source['tel${slot}PhoneNumber'],
        source['tel${slot}CountryCode'],
      );
      if (number != null) unique[number.international] = number;
    }
    return List.unmodifiable(unique.values);
  }

  // Optional: older privateAccommDetail databases have no WhatsApp column.
  ContactNumber? get whatsAppNumber =>
      ContactNumber.internationalNumber(source['whatsAppNumber']);
  String? get email => text(source, 'email');
  final int id, locationId;
  final String name;
  final String? description, address, bookingUrl, websiteUrl, rateNotes;
  final double? singleRateMin, singleRateMax, doubleRateMin, doubleRateMax;
  final LatLng? position;
  final List<String> imageUrls;
  String? get imageUrl => imageUrls.firstOrNull;
  Accommodation.fromRow(super.r, String prefix)
    : id = integer(r, 'ID'),
      locationId = integer(r, 'locationID'),
      name = title(r, '${prefix}Name'),
      description = text(r, '${prefix}AdditionalComments'),
      address = text(r, '${prefix}StreetAdress'),
      bookingUrl = text(r, '${prefix}BookingDotComURL'),
      websiteUrl = text(r, '${prefix}WebsiteURL'),
      rateNotes = text(r, 'rateNotes'),
      singleRateMin = optionalDouble(r, 'onedPersonRateMin'),
      singleRateMax = optionalDouble(r, 'onedPersonRateMax'),
      doubleRateMin = optionalDouble(r, 'twoPersonRateMin'),
      doubleRateMax = optionalDouble(r, 'twodPersonRateMax'),
      position = coordinate(r, 'gps_lat', 'gps_lng'),
      imageUrls = List.unmodifiable([
        for (var i = 1; i <= 4; i++)
          if (text(r, '${prefix}pic${i}URL') != null)
            text(r, '${prefix}pic${i}URL')!,
      ]);
}

class Albergue extends Accommodation {
  final int? numberOfBeds, numberOfDorms;
  bool? _facility(String key) => switch (source[key]) {
    1 => true,
    0 => false,
    _ => null,
  };
  bool? get washingMachine => _facility('washingMachineAvailable');
  bool? get dryer => _facility('dryingMachineAvailable');
  bool? get communalMeal => _facility('communalMealAvailable');
  bool? get kitchen => _facility('kitchenFacilitiesAvailable');
  final String? openingPeriod, checkInOpens, checkInCloses, checkInTimes;
  Albergue.fromRow(Row r)
    : numberOfBeds = optionalInt(r, 'numberOfBeds'),
      numberOfDorms = optionalInt(r, 'numberOfDorms'),
      openingPeriod = text(r, 'openingPeriod'),
      checkInTimes =
          text(r, 'checkInTimes') ??
          (text(r, 'check_in_opens') == null
              ? null
              : '${text(r, 'check_in_opens')} - ${text(r, 'check_in_closes') ?? 'not recorded'}'),
      checkInOpens = text(r, 'check_in_opens'),
      checkInCloses = text(r, 'check_in_closes'),
      super.fromRow(r, 'albergue');
}

class PrivateAccommodation extends Accommodation {
  // The existing privateAccommDetail table has no image columns.
  PrivateAccommodation.fromRow(Row r) : super.fromRow(r, 'privateAccomm');
}

class Path extends SourceRecord {
  final int id, stageId, originLocationId, destinationLocationId;
  final double? distanceMeters, timeSeconds;
  Path.fromRow(super.r)
    : id = integer(r, 'pathID'),
      stageId = integer(r, 'stageID'),
      originLocationId = integer(r, 'originLoc'),
      destinationLocationId = integer(r, 'destinationLoc'),
      distanceMeters = optionalDouble(r, 'distance_metres'),
      timeSeconds = optionalDouble(r, 'time_seconds');
}

class TrackPoint extends SourceRecord {
  final int id, pathId;
  final int? previousTrackPointId;
  final LatLng position;
  final bool isWaypoint;
  final double? elevation,
      distance3dMeters,
      slopeAngleDegrees,
      weightedDistance;
  final String? waypointName;
  TrackPoint.fromRow(super.r, {this.waypointName})
    : id = integer(r, 'track_point_id'),
      pathId = integer(r, 'pathID'),
      previousTrackPointId = optionalInt(r, 'previous_track_point_id'),
      position =
          coordinate(r, 'latitude', 'longitude') ??
          (throw FormatException(
            'Invalid coordinate in track point ${r['track_point_id']}',
          )),
      isWaypoint = optionalInt(r, 'waypoint') == 1,
      elevation = optionalDouble(r, 'elevation'),
      distance3dMeters =
          optionalDouble(r, 'distance_3d_meters') ??
          optionalDouble(r, '3D-Distance'),
      slopeAngleDegrees = optionalDouble(r, 'slope_angle_degrees'),
      weightedDistance = optionalDouble(r, 'weighted_distance');
  TrackPoint named(String label) =>
      TrackPoint.fromRow(source, waypointName: label);
}

/// A clickable rectangle in the published map's original image pixels.
class MapHotspot {
  final int id;
  final Location location;
  final double left, top, right, bottom;
  MapHotspot.fromRow(Row row)
    : id = integer(row, 'hotspotId'),
      location = Location.fromRow(row),
      left = optionalDouble(row, 'TLX1920') ?? double.nan,
      top = optionalDouble(row, 'TLY1920') ?? double.nan,
      right = optionalDouble(row, 'BRX1920') ?? double.nan,
      bottom = optionalDouble(row, 'BRY1920') ?? double.nan;

  bool get isValid =>
      [left, top, right, bottom].every((n) => n.isFinite) &&
      left >= 0 &&
      top >= 0 &&
      right > left &&
      bottom > top;
}
