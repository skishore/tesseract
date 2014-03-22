class @Sketchpad extends Canvas
  constructor: (@elt, @mouse) ->
    super @elt
    @context.canvas.height = do @elt.height
    @context.canvas.width = do @elt.width
    do @set_line_style
    # Set mouse event handlers based on the type of mouse interaction.
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
