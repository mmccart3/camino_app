import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show Distance, LengthUnit;
import '../data/elevation_profile.dart';
import 'app_title.dart';

class ElevationChart extends StatelessWidget {
  final ElevationProfile profile;
  final ElevationMatch? current;
  final ElevationPoint? selected;
  final ValueChanged<ElevationPoint>? onSelect;
  const ElevationChart({
    super.key,
    required this.profile,
    this.current,
    this.selected,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (profile.sampleCount < 2 || profile.length <= 0) {
      return const Text(
        'Elevation samples are not available for this stage yet.',
      );
    }
    return Semantics(
      label:
          'Elevation profile for ${profile.stage.name}. Horizontal axis: sampled distance in kilometres. Vertical axis: elevation in metres.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final chart = GestureDetector(
            onTapUp: onSelect == null
                ? null
                : (event) {
                    final fraction =
                        ((event.localPosition.dx - 52) /
                                math.max(1, width - 68))
                            .clamp(0.0, 1.0);
                    final target = profile.length * fraction;
                    ElevationPoint? nearest;
                    var best = double.infinity;
                    for (final section in profile.sections) {
                      for (final point in section.points) {
                        final delta =
                            (section.offsetMetres +
                                    point.distanceMetres -
                                    target)
                                .abs();
                        if (delta < best) {
                          best = delta;
                          nearest = point;
                        }
                      }
                    }
                    if (nearest != null) onSelect!(nearest);
                  },
            child: CustomPaint(
              size: Size(width, 250),
              painter: ElevationPainter(profile, current, selected),
            ),
          );
          return SizedBox(
            height: 250,
            child: onSelect == null
                ? chart
                : InteractiveViewer(minScale: 1, maxScale: 6, child: chart),
          );
        },
      ),
    );
  }
}

class ElevationPainter extends CustomPainter {
  final ElevationProfile profile;
  final ElevationMatch? current;
  final ElevationPoint? selected;
  ElevationPainter(this.profile, this.current, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    final points = profile.sections.expand((s) => s.points).toList();
    if (points.length < 2 || size.width < 80 || profile.length <= 0) return;
    final low =
        (points.map((p) => p.elevationMetres).reduce(math.min) / 100).floor() *
        100.0;
    final high = math.max(
      low + 100,
      (points.map((p) => p.elevationMetres).reduce(math.max) / 100).ceil() *
          100.0,
    );
    final area = Rect.fromLTRB(52, 24, size.width - 16, size.height - 48);
    double x(double metres) => area.left + metres / profile.length * area.width;
    double y(double elevation) =>
        area.bottom - (elevation - low) / (high - low) * area.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = caminoBlue);
    void label(String text, Offset position, {bool centered = false}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        centered ? position - Offset(painter.width / 2, 0) : position,
      );
    }

    label('m', const Offset(8, 4));
    for (var i = 0; i <= 4; i++) {
      final elevation = low + (high - low) * i / 4;
      canvas.drawLine(
        Offset(area.left, y(elevation)),
        Offset(area.right, y(elevation)),
        Paint()..color = Colors.white24,
      );
      label('${elevation.round()}', Offset(4, y(elevation) - 6));
      final distance = profile.length * i / 4;
      label(
        (distance / 1000).toStringAsFixed(1),
        Offset(x(distance), area.bottom + 8),
        centered: true,
      );
    }
    label(
      'Sampled distance (km)',
      Offset(size.width / 2, size.height - 17),
      centered: true,
    );
    canvas.save();
    canvas.clipRect(area.inflate(5));
    const geography = Distance();
    for (final section in profile.sections) {
      // Each path is drawn independently, even at adjacent horizontal positions.
      final line = Path();
      ElevationPoint? previous;
      for (final point in section.points) {
        final px = x(section.offsetMetres + point.distanceMetres),
            py = y(point.elevationMetres);
        final broken =
            previous == null ||
            geography.as(LengthUnit.Meter, previous.position, point.position) >
                math.max(
                  25,
                  (point.distanceMetres - previous.distanceMetres) * 2,
                );
        if (broken) {
          line.moveTo(px, py);
        } else {
          line.lineTo(px, py);
        }
        previous = point;
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = caminoYellow
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
    void marker(double metres, double elevation, Color color) {
      final point = Offset(x(metres), y(elevation));
      canvas.drawCircle(point, 6, Paint()..color = Colors.black);
      canvas.drawCircle(point, 4, Paint()..color = color);
    }

    final chosen = selected;
    if (chosen != null) {
      final section = profile.sections
          .where((s) => s.path.id == chosen.pathId)
          .firstOrNull;
      if (section != null) {
        marker(
          section.offsetMetres + chosen.distanceMetres,
          chosen.elevationMetres,
          Colors.white,
        );
      }
    }
    final fix = current;
    if (fix != null) {
      marker(fix.chartDistance, fix.point.elevationMetres, Colors.orangeAccent);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ElevationPainter oldDelegate) =>
      oldDelegate.profile != profile ||
      oldDelegate.current != current ||
      oldDelegate.selected != selected;
}
