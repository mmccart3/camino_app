import 'dart:io';
import 'package:camino_app/services/place_search.dart';

// Dependency-free regression check: dart run test/place_search_check.dart
void main() {
  for (final pair in [
    ['León', 'leon'],
    ['Logroño', 'LOGRONO'],
    ['Mañeru', 'maneru'],
    ['Saint-Jean-Pied-de-Port', 'pied'],
    ['Arzúa', 'ARZUA'],
    ['Le\u006f\u0301n', 'leon'],
    ['Leon', 'León'],
    ['  San   Martín del Camino ', 'san martin'],
    ['O Cebreiro', ''],
  ]) {
    if (!matchesPlaceName(pair[0], pair[1])) {
      throw StateError('Did not match: $pair');
    }
  }
  if (matchesPlaceName('León', 'Logroño')) {
    throw StateError('Unrelated locations must not match');
  }
  stdout.writeln('All place-search regression checks passed.');
}
