fix_line_height = (elt) ->
  font_size = parseInt elt.css 'font-size'
  line_height = parseInt elt.css 'line-height'
  elt.css 'font-size', (Math.floor font_size*elt.height()/line_height) + 'px'


window.onload = ->
  ocr_result = $('.ocr-result')
  reset = $('.reset')
  skip = $('.skip')
  for elt in [ocr_result, reset, skip]
    fix_line_height do elt.parent

  mouse = new Mouse
  sketchpad = new Sketchpad $('.sketchpad'), mouse

  buffer = new Canvas $('.buffer')

  sketchpad.changed = =>
    buffer.fill 'white'
    buffer.copy_from sketchpad
    base64_image = do buffer.get_base64_image
    $.post '/ocr', base64_image: base64_image, (data) =>
      ocr_result.text data.result

  reset.click =>
    do sketchpad.clear
    ocr_result.text ''
