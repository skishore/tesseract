class @Canvas
  constructor: (@elt) ->
    @context = elt[0].getContext '2d'
    @context.canvas.height = do @elt.height
    @context.canvas.width = do @elt.width
    do @set_line_style

  set_line_style: =>
    @context.lineCap = 'round'
    @context.lineJoin = 'round'
    @context.lineWidth = 4
    @context.strokeStyle = 'black'

  clear: =>
    @context.clearRect 0, 0, @context.canvas.width, @context.canvas.height

  draw_line: (start, end) =>
    do @context.beginPath
    @context.moveTo start.x, start.y
    @context.lineTo end.x, end.y
    do @context.stroke
    do @context.closePath
