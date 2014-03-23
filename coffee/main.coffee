fix_line_height = (elt) ->
  elt.css 'font-size', (Math.floor elt.height()/2) + 'px'


window.onload = ->
  ocr_result = $('.ocr-result')
  controls = $('.controls')
  for elt in [ocr_result, controls]
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
