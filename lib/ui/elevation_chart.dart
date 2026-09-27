import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show Distance, LengthUnit;
import '../data/elevation_profile.dart';
import 'app_title.dart';

class ElevationChart extends StatefulWidget {
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
  State<ElevationChart> createState() => _ElevationChartState();
}

class _ElevationChartState extends State<ElevationChart> {
  final transformation = TransformationController();
  ElevationProfile get profile => widget.profile;
  ElevationMatch? get current => widget.current;
  ElevationPoint? get selected => widget.selected;
  ValueChanged<ElevationPoint>? get onSelect => widget.onSelect;

  @override
  void dispose() {
    transformation.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ElevationChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      transformation.value = Matrix4.identity();
    }
  }

  void zoom(double factor, double width) {
    final old = transformation.value;
    final scale = old.getMaxScaleOnAxis();
    final next = (scale * factor).clamp(1.0, 8.0);
    final tx = (width / 2 - (width / 2 - old.entry(0, 3)) / scale * next).clamp(
      -width * (next - 1),
      0.0,
    );
    final ty = (160 - (160 - old.entry(1, 3)) / scale * next).clamp(
      -320 * (next - 1),
      0.0,
    );
    transformation.value = Matrix4.diagonal3Values(next, next, 1)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
  }

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
              key: const ValueKey('elevation-canvas'),
              size: Size(width, 320),
              painter: ElevationPainter(profile, current, selected),
            ),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 320,
                child: InteractiveViewer(
                  transformationController: transformation,
                  minScale: 1,
                  maxScale: 8,
                  panEnabled: true,
                  scaleEnabled: true,
                  child: chart,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Zoom out',
                    onPressed: () => zoom(1 / 1.5, width),
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    tooltip: 'Zoom in',
                    onPressed: () => zoom(1.5, width),
                    icon: const Icon(Icons.add),
                  ),
                  TextButton(
                    onPressed: () => transformation.value = Matrix4.identity(),
                    child: const Text('Reset view'),
                  ),
                ],
              ),
              const Text(
                'Pinch or use + / − to zoom; drag to pan when zoomed.',
                style: TextStyle(fontSize: 12),
              ),
            ],
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
    final area = Rect.fromLTRB(52, 96, size.width - 16, size.height - 48);
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
    final landmarks = profile.landmarks;
    for (var i = 0; i < landmarks.length; i++) {
      final match = landmarks[i].match;
      final anchorX = landmarks.length == 1
          ? area.center.dx
          : area.left + 12 + i * (area.width - 24) / (landmarks.length - 1);
      final anchorY = 14.0 + (i % 3) * 24;
      final point = Offset(
        x(match.chartDistance),
        y(match.point.elevationMetres),
      );
      canvas.drawLine(
        Offset(anchorX, anchorY + 10),
        point,
        Paint()
          ..color = Colors.white54
          ..strokeWidth = 1,
      );
      canvas.drawCircle(point, 3, Paint()..color = Colors.white);
    }
    for (var i = 0; i < landmarks.length; i++) {
      final anchorX = landmarks.length == 1
          ? area.center.dx
          : area.left + 12 + i * (area.width - 24) / (landmarks.length - 1);
      final anchorY = 14.0 + (i % 3) * 24;
      canvas.drawCircle(
        Offset(anchorX, anchorY),
        10,
        Paint()..color = const Color(0xFF102F50),
      );
      label('${i + 1}', Offset(anchorX, anchorY - 6), centered: true);
    }
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
      final point = Offset(x(fix.chartDistance), y(fix.point.elevationMetres));
      canvas.drawLine(
        point,
        Offset(point.dx, area.bottom),
        Paint()
          ..color = Colors.orangeAccent
          ..strokeWidth = 2,
      );
      canvas.drawCircle(point, 13, Paint()..color = Colors.black87);
      canvas.drawCircle(point, 11, Paint()..color = Colors.white);
      canvas.drawCircle(point, 8, Paint()..color = Colors.orangeAccent);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ElevationPainter oldDelegate) =>
      oldDelegate.profile != profile ||
      oldDelegate.current != current ||
      oldDelegate.selected != selected;
}
