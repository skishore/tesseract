class @Sketchpad extends Canvas
  constructor: (@elt, @mouse) ->
    @elt.height do @elt.parent().outerHeight
    @elt.width do @elt.parent().outerWidth
    super @elt
    $(document).bind @mouse.down_handler, @mousedown
    $(document).bind @mouse.move_handler, @mousemove
    $(document).bind @mouse.up_handler, @mouseup

  get_cursor: (e) =>
    offset = do @elt.offset
    x: 1.0*(e.pageX - offset.left)*@context.canvas.width/do @elt.width
    y: 1.0*(e.pageY - offset.top)*@context.canvas.height/do @elt.height

  mousedown: (e) =>
    @cursor = @get_cursor e.originalEvent
    do e.preventDefault

  mousemove: (e) =>
    [last_cursor, @cursor] = [@cursor, @get_cursor e.originalEvent]
    if last_cursor and @cursor
      if @mouse.mouse_down or @mouse.touch_enabled
        @draw_line last_cursor, @cursor
    do e.stopPropagation

  mouseup: (e) =>
    do @changed
