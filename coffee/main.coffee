window.onload = ->
  mouse = new Mouse
  sketchpad = new Sketchpad $('.sketchpad'), mouse

  buffer = new Canvas $('.buffer')

  $(document).keydown (e) =>
    if e.keyCode == 13
      buffer.fill 'white'
      buffer.copy_from sketchpad
      base64_image = do buffer.get_base64_image
      $.post '/ocr', base64_image: base64_image, (data) ->
        console.log data
