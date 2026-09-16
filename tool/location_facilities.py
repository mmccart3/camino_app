"""Offline guide enrichment: fetch -> propose -> review JSON -> apply.

Uses Python's standard library. No database writes during fetch or propose.
Run --help for the commands. Sources are OpenStreetMap (ODbL).
"""
from contextlib import closing
import argparse
import datetime as dt
import hashlib
import json
import math
from pathlib import Path
import sqlite3
import time
import urllib.error
import urllib.parse
import urllib.request

COLUMNS = {'bar_cafe': 'hasBarCafe', 'pharmacy': 'hasPharmacy', 'grocery': 'hasGroceryStore'}
NON_SETTLEMENT = ('exit', 'detour', 'splits', 'route splits', 'rejoin', 'leave ', 'alto ', 'col ', 'fountain', 'shelter', 'virgen d', 'ermita', 'winery', 'geographic centre', 'cruz de ferro', 'refreshments van', 'parque ', 'monte del gozo')

def locations(database):
    with closing(sqlite3.connect(Path(database).resolve().as_uri() + '?mode=ro', uri=True)) as db:
        db.row_factory = sqlite3.Row
        return [dict(r) for r in db.execute('SELECT ID,locationName,latitude,longitude FROM locations ORDER BY ID')]

def usable(row):
    lat, lon = row.get('latitude'), row.get('longitude')
    return isinstance(lat, (int,float)) and isinstance(lon, (int,float)) and 41 < lat < 44 and -10 < lon < 0

def distance(a, b):
    la, lo, lb, ln = map(math.radians, [a['latitude'], a['longitude'], b['latitude'], b['longitude']])
    return 12742000 * math.asin(min(1,math.sqrt(math.sin((lb-la)/2)**2 + math.cos(la)*math.cos(lb)*math.sin((ln-lo)/2)**2)))

def category(tags):
    if tags.get('opening_hours') == 'closed' or tags.get('disused:amenity') or tags.get('disused:shop'):
        return None
    if any(tags.get(k) in ('yes','closed','disused','demolished') for k in ('disused','abandoned','demolished')) or tags.get('access') in ('private','no'):
        return None
    if tags.get('amenity') in ('bar','cafe','pub'): return 'bar_cafe'
    if tags.get('amenity') == 'pharmacy': return 'pharmacy'
    if tags.get('shop') in ('supermarket','convenience','grocery'): return 'grocery'
    return None

def fetch(database, output, endpoint):
    output=Path(output)
    if output.exists(): raise ValueError('Snapshot already exists; choose a new filename for a new fetch.')
    good=[r for r in locations(database) if usable(r)]
    output.parent.mkdir(parents=True,exist_ok=True)
    merged={}; batches=[]
    for west in range(-9,-1):
        subset=[r for r in good if west<=r['longitude']<west+1]
        if not subset: continue
        bbox=f"{min(r['latitude'] for r in subset)-.015},{min(r['longitude'] for r in subset)-.02},{max(r['latitude'] for r in subset)+.015},{max(r['longitude'] for r in subset)+.02}"
        query=f'[out:json][timeout:45];(nwr[amenity~"^(bar|cafe|pub|pharmacy)$"]({bbox});nwr[shop~"^(supermarket|convenience|grocery)$"]({bbox}););out center tags;'
        cache=output.parent/(output.stem+'_'+hashlib.sha256(query.encode()).hexdigest()[:12]+'.json')
        if cache.exists(): payload=json.loads(cache.read_text(encoding='utf-8'))
        else:
            request=urllib.request.Request(endpoint+'?'+urllib.parse.urlencode({'data':query}), headers={'User-Agent':'SaintJeanToSantiago-FacilityReview/1.0'})
            try:
                with urllib.request.urlopen(request,timeout=60) as response: payload=json.load(response)
            except urllib.error.HTTPError as error:
                if error.code != 504: raise
                time.sleep(15)
                with urllib.request.urlopen(request,timeout=60) as response: payload=json.load(response)
            if payload.get('remark') or not isinstance(payload.get('elements'),list): raise ValueError(f'Incomplete response: {payload.get("remark")}')
            payload['retrievedAt']=dt.datetime.now(dt.timezone.utc).isoformat()
            cache.write_text(json.dumps(payload,ensure_ascii=False),encoding='utf-8')
            time.sleep(10)
        for element in payload['elements']: merged[(element['type'],element['id'])]=element
        batches.append({'query':query,'retrievedAt':payload['retrievedAt']})
        print(f"Longitude {west}: {len(payload['elements'])} features cached",flush=True)
    payload={'elements':list(merged.values()),'camino_fetch':{'retrievedAt':min(b['retrievedAt'] for b in batches),'endpoint':endpoint,'batches':batches}}
    output.write_text(json.dumps(payload,ensure_ascii=False),encoding='utf-8')
    print(f"Cached {len(payload['elements'])} OSM features in {output}")

def propose(database, snapshot, output):
    rows=locations(database); valid=[r for r in rows if usable(r)]
    raw=json.loads(Path(snapshot).read_text(encoding='utf-8')); candidates=[]
    for element in raw['elements']:
        tags=element.get('tags',{}); kind=category(tags)
        if not kind: continue
        pos=element.get('center',element)
        if 'lat' not in pos or 'lon' not in pos: continue
        point={'latitude':pos['lat'],'longitude':pos['lon']}
        near=sorted([(distance(r,point),r) for r in valid],key=lambda pair:pair[0])
        if near[0][0]>750: continue
        for metres, loc in near:
            if metres>750: break
            ambiguous=any(other['ID']!=loc['ID'] and abs(d-metres)<150 for d,other in near if d<=750)
            special=any(word in loc['locationName'].lower() for word in NON_SETTLEMENT)
            suggested=metres<=300 and loc['ID']==near[0][1]['ID'] and not ambiguous and not special and bool(tags.get('name'))
            candidates.append({'locationID':loc['ID'],'locationName':loc['locationName'],'category':kind,
                'osmType':element['type'],'osmID':element['id'],'name':tags.get('name') or tags.get('brand') or '(unnamed)',
                **point,'distanceMetres':round(metres,1),'sourceURL':f"https://www.openstreetmap.org/{element['type']}/{element['id']}",
                'tags':tags,'suggestion':'strong' if suggested else 'review',
                'reason':'Named, nearest location, within 300 m' if suggested else 'Distant, competing location, unnamed or route landmark: needs review',
                'decision':'pending','reviewNote':''})
    report={'schemaVersion':1,'retrievedAt':raw['camino_fetch']['retrievedAt'],
      'snapshotSHA256':hashlib.sha256(Path(snapshot).read_bytes()).hexdigest(),
      'locations':rows,'candidates':sorted(candidates,key=lambda r:(r['locationID'],r['category'],r['distanceMetres']))}
    Path(output).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'{len(candidates)} proposed location/facility matches; all await explicit review decisions.')

def apply(database, review, output):
    report=json.loads(Path(review).read_text(encoding='utf-8'))
    if any(r['decision'] not in ('accept','defer','reject') for r in report['candidates']):
        raise ValueError('Review every candidate before applying (accept/defer/reject).')
    if locations(database)!=report['locations']: raise ValueError('Locations changed since proposal; regenerate the review.')
    output=Path(output)
    if output.exists(): raise ValueError('Output exists; will not overwrite.')
    output.parent.mkdir(parents=True,exist_ok=True)
    with closing(sqlite3.connect(Path(database).resolve().as_uri()+'?mode=ro',uri=True)) as source, closing(sqlite3.connect(output)) as db:
        source.backup(db)
        with db:
            existing={r[1] for r in db.execute('PRAGMA table_info(locations)')}
            for column in COLUMNS.values():
                for name,definition in [(column,'INTEGER CHECK ("'+column+'" IN (0,1) OR "'+column+'" IS NULL)'),(column+'Source','TEXT'),(column+'CheckedAt','TEXT')]:
                    if name not in existing: db.execute(f'ALTER TABLE locations ADD COLUMN "{name}" {definition}')
            db.execute('''CREATE TABLE IF NOT EXISTS locationFacilities (
              locationID INTEGER NOT NULL, category TEXT NOT NULL, osmType TEXT NOT NULL, osmID INTEGER NOT NULL,
              name TEXT, latitude REAL, longitude REAL, distanceMetres REAL, sourceURL TEXT,
              retrievedAt TEXT, tagsJSON TEXT, decision TEXT, reviewNote TEXT,
              PRIMARY KEY(locationID,category,osmType,osmID))''')
            db.execute('DELETE FROM locationFacilities')
            for row in report['candidates']:
                db.execute('INSERT OR REPLACE INTO locationFacilities VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',(
                  row['locationID'],row['category'],row['osmType'],row['osmID'],row['name'],row['latitude'],row['longitude'],row['distanceMetres'],row['sourceURL'],report['retrievedAt'],json.dumps(row['tags'],ensure_ascii=False),row['decision'],row['reviewNote']))
            for loc in report['locations']:
                for kind,column in COLUMNS.items():
                    accepted=[r for r in report['candidates'] if r['locationID']==loc['ID'] and r['category']==kind and r['decision']=='accept']
                    current=db.execute(f'SELECT "{column}","{column}Source" FROM locations WHERE ID=?',(loc['ID'],)).fetchone()
                    # Never overwrite a manually recorded yes/no. A later OSM search
                    # with no accepted match clears only this tool's previous assertion.
                    if current[0] is not None and not (current[1] or '').startswith('OSM reviewed:'): continue
                    urls='; '.join(r['sourceURL'] for r in accepted)
                    db.execute(f'UPDATE locations SET "{column}"=?,"{column}Source"=?,"{column}CheckedAt"=? WHERE ID=?',
                      (1 if accepted else None,'OSM reviewed: '+urls if accepted else None,report['retrievedAt'] if accepted else None,loc['ID']))
        assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
    print(f'Created {output}; no absence flags inferred from missing OSM data.')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='command',required=True)
    f=sub.add_parser('fetch');f.add_argument('database');f.add_argument('output');f.add_argument('--endpoint',default='https://overpass.private.coffee/api/interpreter')
    p=sub.add_parser('propose');p.add_argument('database');p.add_argument('snapshot');p.add_argument('output')
    a=sub.add_parser('apply');a.add_argument('database');a.add_argument('review');a.add_argument('output')
    args=vars(parser.parse_args());command=args.pop('command');globals()[command](**args)

if __name__=='__main__': main()
