fix_line_height = (elt) ->
  font_size = parseInt elt.css 'font-size'
  line_height = parseInt elt.css 'line-height'
  elt.css 'font-size', (Math.floor font_size*elt.height()/line_height) + 'px'


window.onload = ->
  ocr_result = $('.ocr-result')
  controls = $('.controls')
  for elt in [do ocr_result.parent, controls]
    fix_line_height elt

  mouse = new Mouse
  sketchpad = new Sketchpad $('.sketchpad'), mouse

  buffer = new Canvas $('.buffer')

  sketchpad.changed = =>
    buffer.fill 'white'
    buffer.copy_from sketchpad
    base64_image = do buffer.get_base64_image
    $.post '/ocr', base64_image: base64_image, (data) ->
      ocr_result.text data.result
