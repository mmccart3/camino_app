import argparse, csv, hashlib, json, re, sqlite3
from pathlib import Path
from zipfile import ZipFile
from lxml import etree as E

NS={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
W='{'+NS['w']+'}'
MARKS={('Wingdings 3','F05F'):'DIRECTIONS',('Wingdings','F046'):'HISTORY'}
OTHER={('Wingdings','F028'):' Tel: ',('Webdings','F0E4'):' Meal: ',('Webdings','F080'):' per person ',('Webdings','F069'):' Tourist information: '}
def clean(t):
    t = re.sub(r'(?:per person\s*){2}', 'per double/twin room ', t)
    return re.sub(r'\s+', ' ', t).strip()

def extract(doc, mapping):
    with ZipFile(doc) as z:
        root=E.fromstring(z.read('word/document.xml'))
    paragraphs=root.findall('.//w:body/w:p',NS)
    loc=None; result=[]; covered=[]
    for index,p in enumerate(paragraphs):
        if str(index) in mapping['headings']: loc=mapping['headings'][str(index)]
        if index<49 or loc is None: continue
        if str(index) in mapping['covered_by_existing']:
            covered.append({'source_index':index,'existing_ids':mapping['covered_by_existing'][str(index)]});continue
        if str(index) in mapping['skip']: continue
        chunks=[]; pieces=[]; kind=None
        for e in p.iter():
            if e.tag==W+'sym':
                sym=(e.get(W+'font'),e.get(W+'char'))
                if sym in MARKS:
                    if kind is not None: chunks.append((kind,clean(''.join(pieces))))
                    pieces=[];kind=MARKS[sym]
                else: pieces.append(OTHER.get(sym,' '))
            elif e.tag==W+'t': pieces.append(e.text or '')
            elif e.tag in [W+'tab',W+'br']: pieces.append(' ')
        if kind is not None: chunks.append((kind,clean(''.join(pieces))))
        elif index in mapping['plain']+mapping['history']+mapping['extra_directions']:
            kind='HISTORY' if index in mapping['history'] else 'DIRECTIONS' if index in mapping['extra_directions'] else 'PLAIN'
            chunks=[(kind,clean(''.join(pieces)))]
        for part,(kind,text) in enumerate(chunks):
            if not text: continue
            if index in mapping['plain'] and kind!='HISTORY': kind='PLAIN'
            if index==107: text=text.replace('Tourist information: Tourist information', 'Tourist information:')
            if index==213: text='The monument on your left at the start of the descent is to victims of the civil war.'
            if index==230: text=text.split(' A modern')[0]
            if index==932: text=text.split('(1505 m)',1)[1].strip()
            if index in [283,738,806,808,833,931,982,1259,1298]: text=re.sub(r'^H[. ]+','',text)
            location=mapping['location_overrides'].get(str(index),loc)
            # Keep detour context explicit when the database has only an exit/nearby location.
            if index in [1365,1366]: text='Empalme: '+text
            if index==898: text='Detour to Castrillo de los Polvazares: '+text
            urlmatch=re.search(r'(?:https?://|www\.)[^\s<>]+',text)
            url=urlmatch.group(0).rstrip('.,;:') if urlmatch else None
            if url and url.startswith('www.'): url='https://'+url
            country=phone=None
            tel=re.search(r'Tel:\s*(\+?[\d ()-]{8,24})',text)
            if tel:
                digits=re.sub(r'\D','',tel.group(1))
                if len(digits)==9: country,phone=(33 if location in [1,284] else 34),int(digits)
                elif len(digits)==11 and digits[:2] in ['33','34']: country,phone=int(digits[:2]),int(digits[2:])
            result.append({'source_index':index,'part':part,'locationID':location,'paragraphType':kind,'paragraphText':text,'tel1CountryCode':country,'tel1PhoneNumber':phone,'paragraphWebsiteURL':url})
    return result,covered

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--doc',required=True);parser.add_argument('--database',required=True);parser.add_argument('--mapping',required=True);parser.add_argument('--output',required=True);parser.add_argument('--apply',action='store_true');args=parser.parse_args()
    out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
    mapping=json.loads(Path(args.mapping).read_text(encoding='utf-8'))
    rows,covered=extract(args.doc,mapping)
    db=sqlite3.connect(args.database);db.row_factory=sqlite3.Row
    locations={r['ID']:r['locationName'] for r in db.execute('select ID,locationName from locations')}
    existing=list(db.execute('select * from paragraphs'))
    existing_keys={(r['locationID'],clean(r['paragraphText']).casefold()) for r in existing}
    next_id=max(r['ID'] for r in existing)+1
    inserts=[]
    for r in rows:
        assert r['locationID'] in locations
        key=(r['locationID'],clean(r['paragraphText']).casefold())
        if key in existing_keys: continue
        existing_keys.add(key);r['ID']=next_id;next_id+=1
        r['locationName']=locations[r['locationID']];inserts.append(r)
    (out/'import_rows.json').write_text(json.dumps(inserts,ensure_ascii=False,indent=2),encoding='utf-8')
    (out/'covered_existing.json').write_text(json.dumps(covered,indent=2),encoding='utf-8')
    if inserts:
        with (out/'paragraph_import.csv').open('w',encoding='utf-8-sig',newline='') as f:
            w=csv.DictWriter(f,fieldnames=list(inserts[0]));w.writeheader();w.writerows(inserts)
    if args.apply:
        backup=out/'paragraphs_before_import.sqlite'
        if backup.exists(): raise ValueError('Backup exists; refusing to overwrite prior import audit')
        b=sqlite3.connect(backup);db.backup(b);b.close()
        cols=['ID','paragraphType','paragraphText','tel1CountryCode','tel1PhoneNumber','paragraphWebsiteURL','locationID']
        with db:
            db.executemany('INSERT INTO paragraphs ('+','.join(cols)+') VALUES (?,?,?,?,?,?,?)',[[r[k] for k in cols] for r in inserts])
        assert db.execute('pragma integrity_check').fetchone()[0]=='ok'
    print(json.dumps({'existing_preserved':len(existing),'new_rows':len(inserts),'locations_with_new_text':len(set(r['locationID'] for r in inserts)),'types':{k:sum(r['paragraphType']==k for r in inserts) for k in ['PLAIN','DIRECTIONS','HISTORY']},'applied':args.apply}))
    db.close()
if __name__=='__main__':main()
