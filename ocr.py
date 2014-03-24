#!/usr/bin/env python
import base64
import string
import sys

import tesseract


def decode_image(base64_image):
  prefix = 'data:image/png;base64,'
  if not base64_image.startswith(prefix):
    raise ValueError('Unexpected prefix: %s' % (base64_image[:len(prefix)],))
  return base64.b64decode(base64_image[len(prefix):])


def ocr(image):
  api = tesseract.TessBaseAPI()
  api.Init('.', 'eng', tesseract.OEM_DEFAULT)
  api.SetVariable('tessedit_char_whitelist', string.letters[26:])
  api.SetPageSegMode(tesseract.PSM_SINGLE_CHAR)
  tesseract.ProcessPagesBuffer(image, len(image), api)
  result = api.GetUTF8Text()[:1]
  return '?' if result == ' ' else result


if __name__ == '__main__':
  line = sys.stdin.readline()
  image = decode_image(line[:-1])
  print ocr(image)