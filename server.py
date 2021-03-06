#!/usr/bin/env python
import json
import os
from subprocess import (
  PIPE,
  Popen,
)

from tornado.ioloop import IOLoop
from tornado.options import (
  define,
  options,
  parse_command_line,
)
from tornado.web import (
  Application,
  RequestHandler,
  StaticFileHandler,
)

import languages
from model import Model


model = Model()


def ocr(language, base64_image):
  # Call out to a subprocess, because calling tesseract runs a distinct
  # risk of segfaulting, and we don't want to take out the server.
  # Return the detected Unicode character, or None.
  if language not in languages.REGISTRY:
    raise ValueError('Unexpected language: %s' % (language,))
  subprocess = Popen(['./ocr.py', language], stdin=PIPE, stdout=PIPE, stderr=PIPE)
  (stdout, stderr) = subprocess.communicate(base64_image + '\n')
  assert(subprocess.returncode is not None)
  if subprocess.returncode:
    raise RuntimeError(
      "Command './ocr.py' return non-zero exit status %s" %
      (subprocess.returncode,)
    )
  return unichr(int(stdout[:-1])) if stdout else None


class DebugHandler(StaticFileHandler):
  def set_extra_headers(self, path):
    self.set_header(
      'Cache-Control',
      'no-store, no-cache, must-revalidate, max-age=0',
    )


class IndexHandler(RequestHandler):
  def get(self):
    self.render('index.html')


class LanguagesHandler(RequestHandler):
  def get(self):
    self.set_header('Content-Type', 'text/javascript')
    self.write('LANGUAGE_DATA = %s;' % (json.dumps({
      code: language.to_json()
      for (code, language) in languages.REGISTRY.iteritems()
    }),))


class OCRHandler(RequestHandler):
  def post(self):
    language = self.get_argument('language', default=None, strip=False)
    base64_image = self.get_argument('base64_image', default=None, strip=False)
    result = ocr(language, base64_image)
    self.write({
      'success': bool(result),
      'unichr': ord(result) if result else None,
    })


class SaveHandler(RequestHandler):
  def post(self):
    data_json = self.get_argument('data_json', default=None, strip=False)
    model.insert(**json.loads(data_json))


class TrainTestHandler(RequestHandler):
  def get(self):
    self.set_header('Content-Type', 'text/javascript')
    (train_data, test_data) = model.get_train_and_test_data()
    self.write('''
        TRAIN_DATA = %s;
        TEST_DATA = %s;
      ''' % (json.dumps(train_data), json.dumps(test_data))
    )


if __name__ == '__main__':
  define('port', default=1619, help='Port to listen on', type=int)
  define('debug', default=False, help='Run in debug mode', type=bool)
  parse_command_line()
  # Set up the routing table.
  routing = [
    (r'/', IndexHandler),
    (r'/language_data.js', LanguagesHandler),
    (r'/ocr', OCRHandler),
    (r'/save', SaveHandler),
    (r'/train_test.js', TrainTestHandler),
  ]
  static_handler_class = DebugHandler if options.debug else StaticFileHandler
  base_path = os.path.dirname(__file__)
  app = Application(
    routing,
    static_handler_class=static_handler_class,
    static_path=os.path.join(base_path, 'static'),
    template_path=os.path.join(base_path, 'templates'),
  )
  app.listen(options.port)
  if options.debug:
    print 'Listening on port %s...' % (options.port,)
  IOLoop.instance().start()
