"""Read-only audit of the existing Camino SQLite dataset. No third-party packages."""
from pathlib import Path
import hashlib
import json
import sqlite3
import sys

path = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / 'assets/database/camino.sqlite'
db = sqlite3.connect(path.as_uri() + '?mode=ro', uri=True)
db.row_factory = sqlite3.Row
tables = {r['name']: r['sql'] for r in db.execute("SELECT name,sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")}
report = {'file': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
          'integrity_check': [r[0] for r in db.execute('PRAGMA integrity_check')],
          'declared_foreign_key_errors': [list(r) for r in db.execute('PRAGMA foreign_key_check')],
          'tables': {}, 'route_issues': [], 'track_coverage': []}
for name, sql in tables.items():
    quoted = '"' + name.replace('"', '""') + '"'
    rows = db.execute('SELECT * FROM ' + quoted).fetchall()
    report['tables'][name] = {'rows': len(rows), 'ddl': sql,
      'rows_with_unicode_replacement_character': sum(any(isinstance(v, str) and '\ufffd' in v for v in row) for row in rows)}
for stage in db.execute('SELECT * FROM stages ORDER BY ID'):
    paths = db.execute('SELECT * FROM paths WHERE stageID=? ORDER BY pathID', (stage['ID'],)).fetchall()
    current, used = stage['stageStartLocationID'], set()
    while current != stage['stageFinishLocationID']:
        choices = [p for p in paths if p['originLoc'] == current]
        if len(choices) != 1:
            report['route_issues'].append({'stage': stage['ID'], 'location': current, 'outgoing_path_ids': [p['pathID'] for p in choices]})
            break
        edge = choices[0]
        if edge['pathID'] in used:
            report['route_issues'].append({'stage': stage['ID'], 'cycle_path': edge['pathID']})
            break
        used.add(edge['pathID'])
        current = edge['destinationLoc']
    if current == stage['stageFinishLocationID'] and len(used) != len(paths):
        report['route_issues'].append({'stage': stage['ID'], 'unused_paths': sorted({p['pathID'] for p in paths} - used)})
    covered = db.execute('SELECT COUNT(DISTINCT t.pathID), COUNT(*) FROM track_points t JOIN paths p ON p.pathID=t.pathID WHERE p.stageID=?', (stage['ID'],)).fetchone()
    report['track_coverage'].append({'stage': stage['ID'], 'paths': len(paths), 'paths_with_points': covered[0], 'points': covered[1]})
report['orphan_counts'] = {}
for label, query in {
    'path_stage': 'SELECT COUNT(*) FROM paths p LEFT JOIN stages s ON s.ID=p.stageID WHERE s.ID IS NULL',
    'path_origin': 'SELECT COUNT(*) FROM paths p LEFT JOIN locations l ON l.ID=p.originLoc WHERE l.ID IS NULL',
    'path_destination': 'SELECT COUNT(*) FROM paths p LEFT JOIN locations l ON l.ID=p.destinationLoc WHERE l.ID IS NULL',
    'track_path': 'SELECT COUNT(*) FROM track_points t LEFT JOIN paths p ON p.pathID=t.pathID WHERE p.pathID IS NULL',
    'albergue_location': 'SELECT COUNT(*) FROM albergues a LEFT JOIN locations l ON l.ID=a.locationID WHERE l.ID IS NULL',
    'private_location': 'SELECT COUNT(*) FROM privateAccommDetail a LEFT JOIN locations l ON l.ID=a.locationID WHERE l.ID IS NULL',
    'paragraph_location': 'SELECT COUNT(*) FROM paragraphs p LEFT JOIN locations l ON l.ID=p.locationID WHERE p.locationID IS NOT NULL AND l.ID IS NULL',
}.items():
    report['orphan_counts'][label] = db.execute(query).fetchone()[0]
db.close()
print(json.dumps(report, indent=2, ensure_ascii=True))
