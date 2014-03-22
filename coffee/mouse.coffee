class @Mouse
  constructor: ->
    @mouse_down = false
    @touch_enabled = do @is_touch_enabled

    if @touch_enabled
      do @disable_touch_scroll
    else
      do @enable_mouse_handlers

  is_touch_enabled: ->
    # HAX: We test if touch is enabled by testing for a list of user agents...
    devices = /android|webos|iphone|ipad|ipod|blackberry|iemobile|opera mini/i
    devices.test navigator.userAgent

  disable_touch_scroll: ->
    # Disable touch-based scrolling on mobile platforms.
    document.body.addEventListener 'touchmove', ((e) ->
      do e.preventDefault
      false
    ), false

  enable_mouse_handlers: =>
    # Register top-level mouse event listeners that will maintain this class's
    # mouse_down boolean. These listeners are registered on the document, so
    # no other mouse listeners should be set for that object.
    document.onmousedown = =>
      @mouse_down = true
      return

    document.onmouseup = =>
      @mouse_down = false
      return
