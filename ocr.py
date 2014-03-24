#!/usr/bin/env python
import base64
import string
import sys

import tesseract

import languages


# We need to import string else tesseract segfaults. Why would that be??
# In any case, we have a trivial use of it to stop pyflakes from complaining.
string.letters


LANGUAGE = languages.Kannada


def decode_image(base64_image):
  prefix = 'data:image/png;base64,'
  if not base64_image.startswith(prefix):
    raise ValueError('Unexpected prefix: %s' % (base64_image[:len(prefix)],))
  return base64.b64decode(base64_image[len(prefix):])


def ocr(image):
  #  Return a single Unicode character detected by tesseract OCR, or None.
  api = tesseract.TessBaseAPI()
  api.Init('.', LANGUAGE.code, tesseract.OEM_DEFAULT)
  api.SetVariable('tessedit_char_whitelist', LANGUAGE.alphabet.encode('utf8'))
  api.SetPageSegMode(tesseract.PSM_SINGLE_CHAR)
  tesseract.ProcessPagesBuffer(image, len(image), api)
  result = api.GetUTF8Text().decode('utf8').strip()
  if len(result) > 1:
    raise ValueError(u'Got result of length %s: ' % (len(result),) + result)
  return result if result and result in LANGUAGE.alphabet else None


if __name__ == '__main__':
  # Read in a data URL produced by Javascript with an image/png prefix.
  # Print the decimal number of the Unicode code point returned by tesseract OCR.
  # If we were unable to decipher a character, do not print anything.
  line = sys.stdin.readline()
  image = decode_image(line[:-1])
  result = ocr(image)
  if result:
    print ord(result)
