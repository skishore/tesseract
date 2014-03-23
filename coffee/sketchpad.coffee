class @Sketchpad extends Canvas
  constructor: (@elt, @mouse) ->
    # Account for 1px borders.
    @elt.height @elt.parent().outerHeight() - 2
    @elt.width @elt.parent().outerWidth() - 2
    super @elt
    @elt.bind @mouse.down_handler, @mousedown
    @elt.bind @mouse.move_handler, @mousemove

  get_cursor: (e) =>
    offset = do @elt.offset
    x: 1.0*(e.pageX - offset.left)*@context.canvas.width/do @elt.width
    y: 1.0*(e.pageY - offset.top)*@context.canvas.height/do @elt.height

  mousedown: (e) =>
    @cursor = @get_cursor e.originalEvent

  mousemove: (e) =>
    [last_cursor, @cursor] = [@cursor, @get_cursor e.originalEvent]
    if @mouse.mouse_down or @mouse.touch_enabled
      @draw_line last_cursor, @cursor
