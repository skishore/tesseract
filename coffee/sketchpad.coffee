class @Sketchpad extends Canvas
  constructor: (@elt, @mouse) ->
    super @elt
    @context.canvas.height = do @elt.height
    @context.canvas.width = do @elt.width
    do @set_line_style
    # Set mouse event handlers.
    @elt.mousedown @mousedown
    @elt.mousemove @mousemove

  get_cursor: (e) =>
    offset = do @elt.offset
    x: 1.0*(e.pageX - offset.left)*@context.canvas.width/do @elt.width
    y: 1.0*(e.pageY - offset.top)*@context.canvas.height/do @elt.height

  mousedown: (e) =>
    @cursor = @get_cursor e

  mousemove: (e) =>
    [last_cursor, @cursor] = [@cursor, @get_cursor e]
    if @mouse.mouse_down or @mouse.touch_enabled
      @draw_line last_cursor, @cursor
