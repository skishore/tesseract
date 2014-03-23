window.onload = ->
  ocr_result = $('.ocr-result')

  mouse = new Mouse
  sketchpad = new Sketchpad $('.sketchpad'), mouse

  buffer = new Canvas $('.buffer')

  sketchpad.changed = =>
    buffer.fill 'white'
    buffer.copy_from sketchpad
    base64_image = do buffer.get_base64_image
    $.post '/ocr', base64_image: base64_image, (data) ->
      ocr_result.text data.result
