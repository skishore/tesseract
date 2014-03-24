DELAY = 200
LANGUAGE = 'kan'


fix_line_height = (elt) ->
  font_size = parseInt elt.css 'font-size'
  line_height = parseInt elt.css 'line-height'
  elt.css 'font-size', (Math.floor font_size*elt.height()/line_height) + 'px'


get_next_letter = ->
  ALPHABET[Math.floor Math.random()*ALPHABET.length]


render_unichr = (unichr, elt) ->
  elt.html if unichr then "&##{parseInt unichr};" else '?'


window.onload = ->
  ocr_result = $('.ocr-result')
  hint = $('.hint')
  reset = $('.reset')
  next = $('.next')

  # Fix the height on the containers of all the variable divs.
  ocr_parent = do ocr_result.parent
  controls = do reset.parent  # Same as next.parent.
  for elt in [ocr_parent, controls, hint]
    fix_line_height elt

  # Put up a random hint. We rolled a die to get this one.
  hint.text 'A'

  mouse = new Mouse
  sketchpad = new Sketchpad $('.sketchpad'), mouse
  buffer = new Canvas $('.buffer')

  sketchpad.changed = (version) =>
    ocr_parent.stop().animate backgroundColor: '#CCC', DELAY
    buffer.fill 'white'
    buffer.copy_from sketchpad
    base64_image = do buffer.get_base64_image
    $.post '/ocr', language: LANGUAGE, base64_image: base64_image, (data) =>
      # Check that we're still on the given version before updating the UI.
      if sketchpad.last_version == version
        ocr_parent.stop().animate backgroundColor: '#EEE', DELAY
        render_unichr data.unichr, ocr_result

  clear = =>
    do sketchpad.clear
    # HACK: Suppress sketchpad.changed and manually clear ocr_result.
    version = sketchpad.last_version = sketchpad.version
    ocr_parent.animate backgroundColor: '#CCC', DELAY, undefined, =>
      if sketchpad.last_version == version
        ocr_parent.stop().animate backgroundColor: '#EEE', DELAY
        ocr_result.text ''

  reset.click clear

  next.click =>
    hint.text do get_next_letter
    do clear
