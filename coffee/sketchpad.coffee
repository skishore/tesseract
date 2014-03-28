class @Sketchpad extends Canvas
  constructor: (@elt, @mouse) ->
    @elt.height do @elt.parent().outerHeight
    @elt.width do @elt.parent().outerWidth
    super @elt
    $(document).bind @mouse.down_handler, @mousedown
    $(document).bind @mouse.move_handler, @mousemove
    $(document).bind @mouse.up_handler, @mouseup
    @last_version = @version
    @strokes = []

  clear: =>
    @strokes = []
    super

  get_cursor: (e) =>
    offset = do @elt.offset
    result =
      x: 1.0*(e.pageX - offset.left)*@context.canvas.width/do @elt.width
      y: 1.0*(e.pageY - offset.top)*@context.canvas.height/do @elt.height
    if (@in_range result) and (@mouse.mouse_down or @mouse.touch_enabled)
      @strokes[@strokes.length - 1]?.push result
    result

  in_range: (cursor) =>
    (cursor and
     cursor.x >= 0 and cursor.x < @context.canvas.width and
     cursor.y >= 0 and cursor.y < @context.canvas.height)

  mousedown: (e) =>
    @strokes.push []
    @cursor = @get_cursor e.originalEvent
    if (@in_range @cursor) and (@mouse.mouse_down or @mouse.touch_enabled)
      @draw_point @cursor

  mousemove: (e) =>
    [last_cursor, @cursor] = [@cursor, @get_cursor e.originalEvent]
    if (@in_range last_cursor) or (@in_range @cursor)
      if @mouse.mouse_down or @mouse.touch_enabled
        @draw_line last_cursor, @cursor
    do e.stopPropagation

  mouseup: (e) =>
    if @version > @last_version
      @changed @version
    @last_version = @version
