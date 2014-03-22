import os

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


class DebugHandler(StaticFileHandler):
  def set_extra_headers(self, path):
    self.set_header(
      'Cache-Control',
      'no-store, no-cache, must-revalidate, max-age=0',
    )


class IndexHandler(RequestHandler):
  def get(self):
    self.render('index.html')


def main():
  define('port', default=8000, help='Port to listen on', type=int)
  define('debug', default=False, help='Run in debug mode', type=bool)
  parse_command_line()
  # Set up the routing table.
  routing = [
    (r'/', IndexHandler),
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
