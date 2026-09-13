"""Merge matching OpenMapTiles archives without changing geometry coordinates.

Retains all unique geometry/property combinations. Does not conflate differently
clipped features. Requires identical layer versions and extents in overlaps.
"""
import gzip, hashlib, json, sqlite3, sys
from pathlib import Path

def varint(n):
    out = bytearray()
    while n > 127:
        out.append((n & 127) | 128); n >>= 7
    out.append(n)
    return bytes(out)

def readint(b, i):
    n = shift = 0
    while True:
        v = b[i]; i += 1; n |= (v & 127) << shift
        if v < 128: return n, i
        shift += 7
        if shift > 70: raise ValueError('Invalid varint')

def fields(b):
    i = 0
    while i < len(b):
        tag, i = readint(b, i); wire = tag & 7
        if wire == 0: value, i = readint(b, i)
        elif wire == 2:
            length, i = readint(b, i); value = b[i:i+length]; i += length
            assert len(value) == length
        elif wire in (1, 5):
            length = 8 if wire == 1 else 4; value = b[i:i+length]; i += length
            assert len(value) == length
        else: raise ValueError(f'Unsupported wire type {wire}')
        yield tag >> 3, wire, value

def field(n, w, v):
    return varint((n << 3) | w) + (varint(v) if w == 0 else varint(len(v)) + v if w == 2 else v)

def unpack(b):
    i = 0; result = []
    while i < len(b):
        n, i = readint(b, i); result.append(n)
    return result

def layers(data):
    b = gzip.decompress(data) if data[:2] == b'\x1f\x8b' else data
    result = {}
    for n, w, v in fields(b):
        assert n == 3 and w == 2
        f = list(fields(v)); name = next(v for n,w,v in f if n == 1)
        assert name not in result
        result[name] = f
    return result

def features(f):
    keys = [v for n,w,v in f if n == 3]
    values = [v for n,w,v in f if n == 4]
    for n,w,v in f:
        if n != 2: continue
        ff = list(fields(v)); tags = []
        for a,b,c in ff:
            if a == 2: tags.extend(unpack(c) if b == 2 else [c])
        assert len(tags) % 2 == 0
        props = sorted((keys[tags[i]], values[tags[i+1]]) for i in range(0,len(tags),2))
        # IDs may be absent or differ between extracts; geometry/properties define exact duplicates.
        signature = (tuple(props), tuple((a,b,c) for a,b,c in ff if a not in (1,2)))
        yield ff, props, signature

def merge(a, b):
    la, lb = layers(a), layers(b)
    output = []
    for name in dict.fromkeys([*la, *lb]):
        groups = [d[name] for d in (la,lb) if name in d]
        versions = {next((v for n,w,v in f if n == 15),1) for f in groups}
        extents = {next((v for n,w,v in f if n == 5),4096) for f in groups}
        assert len(versions) == len(extents) == 1
        keys = {}; values = {}; seen = set(); fs = []
        for f in groups:
            assert all(n in (1,2,3,4,5,15) for n,w,v in f)
            for ff,props,sig in features(f):
                if sig in seen: continue
                seen.add(sig); tags = []
                for k,v in props:
                    tags.extend([keys.setdefault(k,len(keys)),values.setdefault(v,len(values))])
                item = b''.join(field(n,w,v) for n,w,v in ff if n != 2)
                if tags: item += field(2,2,b''.join(varint(t) for t in tags))
                fs.append(field(2,2,item))
        payload = field(1,2,name)+b''.join(fs)
        payload += b''.join(field(3,2,k) for k in keys)
        payload += b''.join(field(4,2,v) for v in values)
        payload += field(5,0,next(iter(extents)))+field(15,0,next(iter(versions)))
        rebuilt = list(fields(payload))
        assert {sig for _,_,sig in features(rebuilt)} == seen
        output.append(field(3,2,payload))
    return gzip.compress(b''.join(output),mtime=0)

def combine(inputs, output):
    output = Path(output)
    if output.exists(): raise FileExistsError(output)
    out = sqlite3.connect(output)
    out.executescript('CREATE TABLE metadata(name TEXT PRIMARY KEY,value TEXT); CREATE TABLE tiles(zoom_level INTEGER,tile_column INTEGER,tile_row INTEGER,tile_data BLOB,PRIMARY KEY(zoom_level,tile_column,tile_row));')
    metas = []; schemas = {}; counts = []
    for path in inputs:
        c = sqlite3.connect(Path(path).resolve().as_uri()+'?mode=ro',uri=True)
        assert c.execute('pragma quick_check').fetchone()[0] == 'ok'
        meta = dict(c.execute('select name,value from metadata')); metas.append(meta)
        assert meta['format'] == 'pbf'
        for layer in json.loads(meta['json'])['vector_layers']:
            old = schemas.setdefault(layer['id'],dict(layer))
            old['fields'] = {**old['fields'],**layer['fields']}
            old['minzoom'] = min(old['minzoom'],layer['minzoom'])
            old['maxzoom'] = max(old['maxzoom'],layer['maxzoom'])
        count = overlap = 0
        for z,x,y,b in c.execute('select zoom_level,tile_column,tile_row,tile_data from tiles'):
            layers(b) # Validate every tile envelope, including non-overlapping tiles.
            previous = out.execute('select tile_data from tiles where zoom_level=? and tile_column=? and tile_row=?',(z,x,y)).fetchone()
            if previous:
                b = merge(previous[0],b); overlap += 1
            out.execute('insert or replace into tiles values(?,?,?,?)',(z,x,y,b)); count += 1
        counts.append({'file':str(path),'sha256':hashlib.sha256(Path(path).read_bytes()).hexdigest(),'tiles':count,'overlapping_tiles':overlap})
        c.close()
    meta = dict(metas[0]); bounds = [list(map(float,m['bounds'].split(','))) for m in metas]
    meta['bounds'] = ','.join(map(str,[min(b[0] for b in bounds),min(b[1] for b in bounds),max(b[2] for b in bounds),max(b[3] for b in bounds)]))
    meta['json'] = json.dumps({'vector_layers':list(schemas.values())})
    meta['name'] = 'Camino Navarra and stage 1'
    meta['description'] = 'Combined Navarra and stage-1 Aquitaine/Navarra extracts; exact feature duplicates removed.'
    meta['camino:sources'] = json.dumps(counts)
    out.executemany('insert into metadata values(?,?)',meta.items()); out.commit()
    assert out.execute('pragma integrity_check').fetchone()[0] == 'ok'
    out.close(); print(json.dumps(counts,indent=2)); print(output,output.stat().st_size)

if __name__ == '__main__': combine(sys.argv[2:],sys.argv[1])
