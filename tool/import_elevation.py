"""Import elevation samples into a separate SQLite copy, preserving navigation data.

Use --interval for CSVs whose distance column contains a sampling interval.
Otherwise distanceAlongPathMetres must be cumulative and start at zero per path.
"""
import argparse
import csv
import hashlib
import json
import math
from collections import defaultdict
from contextlib import closing
from pathlib import Path
import sqlite3


def metres(a, b):
    lat, lon, lat2, lon2 = map(math.radians, a + b)
    return 12742000 * math.asin(min(1, math.sqrt(
        math.sin((lat2-lat)/2)**2 + math.cos(lat)*math.cos(lat2)*math.sin((lon2-lon)/2)**2)))


def import_samples(database, csv_file, output, interval=False):
    database, csv_file, output = map(Path, (database, csv_file, output))
    if output.exists():
        raise ValueError('Choose a new output filename; existing files are never overwritten.')
    groups = defaultdict(list)
    with csv_file.open(encoding='utf-8-sig', newline='') as stream:
        for line, row in enumerate(csv.DictReader(stream), 2):
            try:
                path_id, sequence = int(row['pathID']), int(row['sequence'])
                distance = float(row.get('distanceAlongPathMetres', row.get('distanceAlongPathMetre', '')))
                elevation, lat, lon = (float(row[k]) for k in ('elevationMetres', 'latitude', 'longitude'))
                if sequence < 0 or not all(math.isfinite(x) for x in (distance, elevation, lat, lon)):
                    raise ValueError('Invalid sequence or non-finite number')
                if not -90 <= lat <= 90 or not -180 <= lon <= 180 or distance < 0:
                    raise ValueError('Invalid coordinate or negative distance')
                groups[path_id].append((sequence, distance, elevation, lat, lon))
            except (KeyError, ValueError) as error:
                raise ValueError(f'CSV line {line}: {error}') from error
    if not groups:
        raise ValueError('CSV has no samples.')
    normalized = []
    report = {'sourceSHA256': hashlib.sha256(csv_file.read_bytes()).hexdigest(),
              'distanceBasis': 'sampling_interval' if interval else 'cumulative', 'paths': []}
    with closing(sqlite3.connect(database.resolve().as_uri()+'?mode=ro', uri=True)) as source:
        source.row_factory = sqlite3.Row
        paths = {r['pathID']: dict(r) for r in source.execute('SELECT * FROM paths')}
        locations = {r['ID']: dict(r) for r in source.execute('SELECT * FROM locations')}
        for path_id, samples in sorted(groups.items()):
            if path_id not in paths:
                raise ValueError(f'Unknown pathID {path_id}')
            samples.sort()
            if len(samples) < 2 or len({s[0] for s in samples}) != len(samples):
                raise ValueError(f'Path {path_id}: need at least two uniquely sequenced samples')
            if interval and (samples[0][1] <= 0 or any(s[1] != samples[0][1] for s in samples)):
                raise ValueError(f'Path {path_id}: interval must be positive and constant')
            if interval and any(b[0] != a[0]+1 for a, b in zip(samples, samples[1:])):
                raise ValueError(f'Path {path_id}: missing sequence; supply cumulative distances instead')
            distances = [i*samples[0][1] for i in range(len(samples))] if interval else [s[1] for s in samples]
            if distances[0] != 0 or any(b <= a for a, b in zip(distances, distances[1:])):
                raise ValueError(f'Path {path_id}: cumulative distances must start at 0 and increase')
            path = paths[path_id]
            gaps = [s[0] for p, s in zip(samples, samples[1:])
                    if metres(p[3:5], s[3:5]) > max(25, (s[1] if interval else s[1]-p[1])*2)]
            def offset(sample, location_id):
                loc = locations.get(location_id, {})
                if loc.get('latitude') is None or loc.get('longitude') is None:
                    return None
                return round(metres(sample[3:5], (loc['latitude'], loc['longitude'])), 1)
            report['paths'].append({'pathID': path_id, 'stageID': path['stageID'], 'samples': len(samples),
                'sampledMetres': distances[-1], 'startOffsetMetres': offset(samples[0], path['originLoc']),
                'endOffsetMetres': offset(samples[-1], path['destinationLoc']), 'gapSequences': gaps})
            for i, (sequence, _, elevation, lat, lon) in enumerate(samples):
                normalized.append((path_id, i, distances[i], elevation, lat, lon, sequence,
                                   report['distanceBasis'], report['sourceSHA256']))
        output.parent.mkdir(parents=True, exist_ok=True)
        with closing(sqlite3.connect(output)) as target:
            source.backup(target)
            with target:
                target.execute('''CREATE TABLE IF NOT EXISTS elevation_points (
                  pathID INTEGER NOT NULL, sequence INTEGER NOT NULL,
                  distanceAlongPathMetres REAL NOT NULL, elevationMetres REAL NOT NULL,
                  latitude REAL NOT NULL, longitude REAL NOT NULL, sourceSequence INTEGER NOT NULL,
                  distanceBasis TEXT NOT NULL, sourceSHA256 TEXT NOT NULL,
                  PRIMARY KEY(pathID, sequence), FOREIGN KEY(pathID) REFERENCES paths(pathID))''')
                for path_id in groups:
                    target.execute('DELETE FROM elevation_points WHERE pathID=?', (path_id,))
                target.executemany('INSERT INTO elevation_points VALUES (?,?,?,?,?,?,?,?,?)', normalized)
            if target.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
                raise ValueError('Database integrity check failed')
    report['sampleCount'] = len(normalized)
    output.with_suffix('.elevation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(f'Imported {len(normalized)} elevation samples across {len(groups)} paths into {output}')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('database'); parser.add_argument('csv_file'); parser.add_argument('output')
    parser.add_argument('--interval', action='store_true', help='Distance contains uniform spacing; first sample is local distance zero')
    import_samples(**vars(parser.parse_args()))
