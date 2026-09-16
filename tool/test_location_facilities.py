from contextlib import closing
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
import location_facilities as f

class FacilityTests(unittest.TestCase):
    def test_categories_exclude_closed_private_and_non_grocers(self):
        self.assertEqual(f.category({'amenity':'pharmacy'}),'pharmacy')
        self.assertEqual(f.category({'shop':'convenience'}),'grocery')
        for tags in [{'shop':'bakery'}, {'amenity':'restaurant'}, {'amenity':'bar','access':'private'}, {'amenity':'cafe','opening_hours':'closed'}, {'amenity':'cafe','disused:amenity':'cafe'}]:
            self.assertIsNone(f.category(tags))

    def test_apply_leaves_unknown_and_preserves_manual_flags(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp=Path(tmp);db=tmp/'original.sqlite'
            with closing(sqlite3.connect(db)) as c:
                c.execute('CREATE TABLE locations (ID INTEGER,locationName TEXT,latitude REAL,longitude REAL,hasPharmacy INTEGER,hasPharmacySource TEXT)')
                c.execute("INSERT INTO locations VALUES(1,'Village',42.5,-2,0,'Owner verified')")
                c.commit()
            rows=f.locations(db)
            record={'locationID':1,'locationName':'Village','category':'bar_cafe','osmType':'node','osmID':1,'name':'Cafe', 'latitude':42.5,'longitude':-2,'distanceMetres':0,'sourceURL':'https://www.openstreetmap.org/node/1','tags':{'amenity':'cafe'},'decision':'accept','reviewNote':'Checked evidence'}
            report={'locations':rows,'retrievedAt':'2026-09-16','candidates':[record]}
            review=tmp/'review.json';review.write_text(json.dumps(report))
            output=tmp/'new.sqlite';f.apply(db,review,output)
            with closing(sqlite3.connect(output)) as c:
                self.assertEqual(c.execute('SELECT hasBarCafe,hasPharmacy,hasGroceryStore FROM locations').fetchone(),(1,0,None))
                self.assertEqual(c.execute('SELECT count(*) FROM locationFacilities').fetchone()[0],1)
            record['decision']='defer';review.write_text(json.dumps(report))
            refreshed=tmp/'refreshed.sqlite';f.apply(output,review,refreshed)
            with closing(sqlite3.connect(refreshed)) as c:
                self.assertEqual(c.execute('SELECT hasBarCafe,hasPharmacy,hasGroceryStore FROM locations').fetchone(),(None,0,None))
            record['decision']='pending';review.write_text(json.dumps(report))
            with self.assertRaises(ValueError): f.apply(db,review,tmp/'bad.sqlite')

if __name__=='__main__':unittest.main()
