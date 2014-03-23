import base64
import os
import string

import tesseract
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


def ocr(image):
  api = tesseract.TessBaseAPI()
  api.Init('.', 'eng', tesseract.OEM_DEFAULT)
  api.SetVariable('tessedit_char_whitelist', string.digits + string.letters)
  api.SetPageSegMode(tesseract.PSM_SINGLE_CHAR)
  tesseract.ProcessPagesBuffer(image, len(image), api)
  return api.GetUTF8Text()[:1]


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
    prefix = 'data:image/png;base64,'
    if not base64_image.startswith(prefix):
      raise ValueError('Unexpected prefix: %s' % (base64_image[:len(prefix)],))
    image = base64.b64decode(base64_image[len(prefix):])
    self.write({'result': ocr(image)})


def main():
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


if __name__ == '__main__':
  main()
