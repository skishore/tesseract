import json
import os
import sqlite3


class Model(object):
  def __init__(self):
    script_path = os.path.realpath(os.path.join(os.getcwd(), __file__))
    self.path = os.path.join(os.path.dirname(script_path), 'tesseract.db')
    self.conn = sqlite3.connect(self.path)
    self.create_tables()

  def create_tables(self):
    with self.conn as cursor:
      cursor.execute('''
        CREATE TABLE IF NOT EXISTS ocr_data (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          data TEXT NOT NULL,
          strokes TEXT NOT NULL,
          dataset TEXT NOT NULL,
          unichr INT NOT NULL,
          ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
      ''')

  def insert(self, data, strokes, dataset, unichr):
    if dataset not in ('train', 'test'):
      raise ValueError('Unexpected dataset: %s' % (dataset,))
    with self.conn as cursor:
      cursor.execute('''
        INSERT INTO ocr_data (data, strokes, dataset, unichr)
        VALUES (?, ?, ?, ?);
      ''', (json.dumps(data), json.dumps(strokes), dataset, unichr))

  def get_train_and_test_data(self):
    # Returns a tuple of dicts (train_data, test_data).
    cursor = self.conn.cursor()
    cursor.execute('SELECT * FROM ocr_data;')
    rows = cursor.fetchall()
    cursor.close()
    # Deserliaze the data from the database.
    data = {'train': [], 'test': []}
    for row in rows:
      data[row[3]].append({
        'data': json.loads(row[1]),
        'strokes': json.loads(row[2]),
        'dataset': row[3],
        'unichr': row[4],
      })
    return (data['train'], data['test'])


model = Model()
