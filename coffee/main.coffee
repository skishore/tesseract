delay = 200


fix_line_height = (elt) ->
  font_size = parseInt elt.css 'font-size'
  line_height = parseInt elt.css 'line-height'
  elt.css 'font-size', (Math.floor font_size*elt.height()/line_height) + 'px'


window.onload = ->
  ocr_result = $('.ocr-result')
  hint = $('.hint')
  reset = $('.reset')
  skip = $('.skip')

  # Fix the height on the containers of all the variable divs.
  ocr_parent = do ocr_result.parent
  controls = do reset.parent  # Same as do skip.parent.
  for elt in [ocr_parent, controls, hint]
    fix_line_height elt

  # Put up a random hint. We rolled a die to get this one.
  hint.text 'A'

  mouse = new Mouse
  sketchpad = new Sketchpad $('.sketchpad'), mouse
  buffer = new Canvas $('.buffer')

  sketchpad.changed = (version) =>
    ocr_parent.stop().animate backgroundColor: '#CCC', delay
    buffer.fill 'white'
    buffer.copy_from sketchpad
    base64_image = do buffer.get_base64_image
    $.post '/ocr', base64_image: base64_image, (data) =>
      # Check that we're still on the given version before updating the UI.
      if sketchpad.last_version == version
        ocr_parent.stop().animate backgroundColor: '#EEE', delay
        ocr_result.text data.result

  reset.click =>
    do sketchpad.clear
    # HACK: Suppress sketchpad.changed and manually clear ocr_result.
    version = sketchpad.last_version = sketchpad.version
    ocr_parent.animate backgroundColor: '#CCC', delay, undefined, =>
      if sketchpad.last_version == version
        ocr_parent.stop().animate backgroundColor: '#EEE', delay
        ocr_result.text ''
