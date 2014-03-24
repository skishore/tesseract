#!/usr/bin/env python
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


def ocr(base64_image):
  # Call out to a subprocess, because calling tesseract runs a distinct
  # risk of segfaulting, and we don't want to take out the server.
  # Return the detected Unicode character, or None.
  subprocess = Popen(['./ocr.py'], stdin=PIPE, stdout=PIPE, stderr=PIPE)
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


class OCRHandler(RequestHandler):
  def post(self):
    base64_image = self.get_argument("base64_image", default=None, strip=False)
    result = ocr(base64_image)
    self.write({
      'success': bool(result),
      'unichr': ord(result) if result else None,
    })


if __name__ == '__main__':
  define('port', default=8000, help='Port to listen on', type=int)
  define('debug', default=False, help='Run in debug mode', type=bool)
  parse_command_line()
  # Set up the routing table.
  routing = [
    (r'/', IndexHandler),
    (r'/ocr', OCRHandler),
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
  IOLoop.instance().start()
