window.onload = ->
  mouse = new Mouse
  sketchpad = new Sketchpad $('.sketchpad'), mouse

  $(document).keydown (e) =>
    if e.keyCode == 13
      base64_image = do sketchpad.get_base64_image
      $.post '/ocr', base64_image: base64_image, (data) ->
        console.log data
