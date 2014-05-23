DELAY = 0
DEMO_MODE = true

LANGUAGE = 'kan'

ALPHABET = LANGUAGE_DATA[LANGUAGE].alphabet_indices
index = -1


fix_line_height = (elt) ->
  font_size = parseInt elt.css 'font-size'
  line_height = parseInt elt.css 'line-height'
  elt.css 'font-size', (Math.floor font_size*elt.height()/line_height) + 'px'


get_next_letter = (offset) ->
  #index = ALPHABET[Math.floor Math.random()*ALPHABET.length]
  index = (index + offset + ALPHABET.length) % ALPHABET.length
  ALPHABET[index]


render_unichr = (unichr, elt) ->
  elt.html if unichr then "&##{parseInt unichr};" else '?'


window.onload = ->
  ocr_result = $('.ocr-result')
  hint = $('.hint')
  reset = $('.reset')
  prev = $('.prev')
  next = $('.next')

  # Fix the height on the containers of all the variable divs.
  ocr_parent = do ocr_result.parent
  controls = do reset.parent  # Same as prev.parent and next.parent.
  for elt in [ocr_parent, controls, hint]
    fix_line_height elt

  # Fix font size for the train/test buttons.
  $('.train, .test').css 'font-size', $('.prev').css 'font-size'

  # Put up a random hint. We rolled a die to get this one.
  render_unichr (get_next_letter 1), hint

  mouse = new Mouse
  sketchpad = new Sketchpad $('.sketchpad'), mouse
  feature = new Feature $('.feature')
  feature.redraw if DEMO_MODE then TEST_DATA[3].data else undefined

  classifier = new Classifier feature, TRAIN_DATA

  sketchpad.changed = (version) =>
    feature.redraw sketchpad.strokes
    [i, sample] = classifier.classify do feature.serialize
    render_unichr sample.unichr, $('.test')
    return
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
    feature.redraw if DEMO_MODE then TRAIN_DATA[index].data else undefined

  reset.click clear

  prev.click =>
    render_unichr (get_next_letter -1), hint
    do clear

  next.click =>
    render_unichr (get_next_letter 1), hint
    do clear

  $('.train, .test').click ->
    data = do feature.serialize
    if data.strokes.length
      data.dataset = $(@).data 'dataset'
      data.unichr = ALPHABET[index]
      if data.dataset == 'test'
        $.post '/save', data_json: JSON.stringify data
        next.trigger 'click'
