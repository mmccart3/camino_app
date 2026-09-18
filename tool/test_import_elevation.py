import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from import_elevation import import_samples


class ImportTests(unittest.TestCase):
    def test_interval_conversion_and_preservation(self):
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            original = folder/'original.sqlite'
            with closing(sqlite3.connect(original)) as db:
                db.executescript('''CREATE TABLE paths(pathID INTEGER PRIMARY KEY, stageID INTEGER, originLoc INTEGER, destinationLoc INTEGER);
                  INSERT INTO paths VALUES (1,1,1,2); INSERT INTO paths VALUES (2,1,2,3);
                  CREATE TABLE locations(ID INTEGER, latitude REAL, longitude REAL);
                  INSERT INTO locations VALUES (1,43,-1); INSERT INTO locations VALUES (2,43,-1.001); INSERT INTO locations VALUES (3,43,-1.002);
                  CREATE TABLE track_points(track_point_id INTEGER, elevation REAL);
                  INSERT INTO track_points VALUES (7,190);''')
            csv_file = folder/'samples.csv'
            csv_file.write_text('pathID,sequence,distanceAlongPathMetre,elevationMetres,latitude,longitude\n'
                               '1,0,10,190,43,-1\n1,1,10,191,43,-1.0001\n'
                               '2,2,10,192,43,-1.001\n2,3,10,193,43,-1.0011\n')
            output = folder/'output.sqlite'
            import_samples(original, csv_file, output, interval=True)
            with closing(sqlite3.connect(output)) as db:
                self.assertEqual(db.execute('SELECT pathID,sequence,distanceAlongPathMetres,sourceSequence FROM elevation_points ORDER BY pathID,sequence').fetchall(),
                                 [(1,0,0,0),(1,1,10,1),(2,0,0,2),(2,1,10,3)])
                self.assertEqual(db.execute('SELECT * FROM track_points').fetchall(), [(7,190)])
            with self.assertRaises(ValueError):
                import_samples(original, csv_file, folder/'not_cumulative.sqlite')
            with self.assertRaises(ValueError):
                import_samples(original, csv_file, output, interval=True)
            csv_file.write_text(csv_file.read_text().replace('2,3,10','2,2,10'))
            with self.assertRaises(ValueError):
                import_samples(original, csv_file, folder/'duplicates.sqlite', interval=True)
            self.assertFalse((folder/'duplicates.sqlite').exists())


if __name__ == '__main__':
    unittest.main()
