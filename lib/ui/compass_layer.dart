import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/compass_heading.dart';

/// A foreground-only magnetic heading; it is never a route/turn instruction.
class CompassLayer extends StatefulWidget {
  final LatLng? position;
  final Stream<dynamic>? events;
  final bool walkingControls;
  final VoidCallback? onCentre, onElevation;
  const CompassLayer({
    super.key,
    this.position,
    this.events,
    this.walkingControls = false,
    this.onCentre,
    this.onElevation,
  });

  @override
  State<CompassLayer> createState() => _CompassLayerState();
}

class _CompassLayerState extends State<CompassLayer>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const channel = EventChannel('camino/compass');
  static final sensorEvents = channel.receiveBroadcastStream();
  final heading = CompassHeading();
  StreamSubscription<dynamic>? subscription;
  Timer? watchdog;
  MapController? map;
  StreamSubscription<MapEvent>? mapEvents;
  late final rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addListener(rotateFrame);
  double rotationStart = 0, rotationDelta = 0;
  bool compassUp = false, rotationPaused = false;

  void rotateFrame() {
    map?.rotate(
      rotationStart + rotationDelta * Curves.easeOut.transform(rotation.value),
    );
  }

  void turnTo(double target) {
    rotation.stop();
    rotationStart = map!.camera.rotation;
    rotationDelta = (target - rotationStart + 540) % 360 - 180;
    rotation.forward(from: 0);
  }

  void toggleRotation() {
    if (compassUp) {
      setState(() {
        compassUp = false;
        rotationPaused = false;
      });
      turnTo(0);
    } else if (heading.degrees != null) {
      setState(() {
        compassUp = true;
        rotationPaused = false;
      });
      turnTo(-heading.degrees!);
    }
  }

  void onMapEvent(MapEvent event) {
    const gestures = {
      MapEventSource.dragStart,
      MapEventSource.onDrag,
      MapEventSource.multiFingerGestureStart,
      MapEventSource.onMultiFinger,
      MapEventSource.doubleTap,
      MapEventSource.doubleTapHold,
      MapEventSource.doubleTapZoomAnimationController,
      MapEventSource.scrollWheel,
      MapEventSource.cursorKeyboardRotation,
      MapEventSource.keyboard,
    };
    if ((compassUp || rotation.isAnimating) &&
        gestures.contains(event.source)) {
      rotation.stop();
      setState(() {
        compassUp = false;
        rotationPaused = true;
      });
    }
  }

  bool visible = false, reliable = false;
  String status = 'Waiting for compass...';
  bool get supported =>
      widget.events != null ||
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = MapController.of(context);
    if (map != controller) {
      unawaited(mapEvents?.cancel());
      map = controller;
      mapEvents = controller.mapEventStream.listen(onMapEvent);
    }
    visible = TickerMode.valuesOf(context).enabled;
    sync();
  }

  void sync() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!visible ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      stop();
      return;
    }
    if (!supported) {
      status = 'Compass unavailable on this device';
      return;
    }
    if (subscription != null) return;
    status = 'Waiting for compass...';
    heading.reset();
    watchdog = Timer(const Duration(seconds: 10), () => unavailable());
    subscription = (widget.events ?? sensorEvents).listen(
      (dynamic event) {
        watchdog?.cancel();
        if (event is! Map ||
            event['heading'] is! num ||
            !(event['heading'] as num).toDouble().isFinite) {
          unavailable();
          return;
        }
        if (!mounted) return;
        setState(() {
          reliable = event['reliable'] == true;
          if (reliable) {
            heading.update((event['heading'] as num).toDouble());
            if (compassUp) turnTo(-heading.degrees!);
          } else {
            heading.reset();
            rotation.stop();
            status = 'Compass needs calibration';
          }
        });
        watchdog = Timer(const Duration(seconds: 15), () => unavailable());
      },
      onError: (Object _) => unavailable(),
      onDone: unavailable,
    );
  }

  void unavailable() {
    if (!mounted) return;
    watchdog?.cancel();
    rotation.stop();
    setState(() {
      heading.reset();
      reliable = false;
      status = 'Compass reading unavailable';
    });
  }

  void stop() {
    rotation.stop();
    unawaited(subscription?.cancel());
    subscription = null;
    watchdog?.cancel();
    heading.reset();
    reliable = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(sync);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stop();
    unawaited(mapEvents?.cancel());
    rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final degrees = heading.degrees;
    final label = degrees == null
        ? status
        : 'Phone facing ${CompassHeading.direction(degrees)} ${degrees.round() % 360}°';
    return Stack(
      children: [
        if (widget.position != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.position!,
                width: 52,
                height: 52,
                rotate: false,
                child: Semantics(
                  label: degrees == null ? 'Your position' : label,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF083B72),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: degrees == null
                        ? const Icon(
                            Icons.my_location,
                            color: Colors.white,
                            size: 28,
                          )
                        : Transform.rotate(
                            angle: CompassHeading.radians(degrees),
                            child: const Icon(
                              Icons.navigation,
                              color: Color(0xFFFFD54F),
                              size: 38,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        Positioned(
          bottom: 56,
          right: 8,
          left: widget.walkingControls ? 8 : null,
          child: Material(
            color: const Color(0xFF083B72),
            borderRadius: BorderRadius.circular(8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                if (widget.walkingControls)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 56),
                      foregroundColor: const Color(0xFFFFD54F),
                      disabledForegroundColor: Colors.white54,
                    ),
                    onPressed: widget.onCentre,
                    icon: const Icon(Icons.my_location, size: 28),
                    label: const Text('Centre on me'),
                  ),
                TextButton.icon(
                  onPressed: compassUp || degrees != null
                      ? toggleRotation
                      : null,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 56),
                    foregroundColor: const Color(0xFFFFD54F),
                    disabledForegroundColor: Colors.white54,
                  ),
                  icon: Icon(
                    compassUp ? Icons.explore : Icons.explore_outlined,
                    size: 28,
                  ),
                  label: Text(
                    compassUp
                        ? 'North up'
                        : rotationPaused
                        ? 'Resume compass'
                        : 'Compass up',
                  ),
                ),
                if (widget.walkingControls)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 56),
                      foregroundColor: const Color(0xFFFFD54F),
                    ),
                    onPressed: widget.onElevation,
                    icon: const Icon(Icons.terrain, size: 28),
                    label: const Text('Elevation'),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Align(
            alignment: Alignment.topLeft,
            child: Tooltip(
              message:
                  'Approximate direction of the top of your screen, relative to magnetic north. '
                  'Hold the phone flat, away from magnets or metal. If needed, move it in a figure of eight. '
                  'This arrow is not a direction to the next waypoint.',
              child: Material(
                color: const Color(0xFF083B72),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    '$label\nMagnetic compass · hold phone flat',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
