class @Canvas
  constructor: (@elt) ->
    @context = elt[0].getContext '2d'
    @context.canvas.height = do @elt.height
    @context.canvas.width = do @elt.width
    do @set_line_style
    do @clear

  set_line_style: =>
    @context.lineCap = 'round'
    @context.lineJoin = 'round'
    @context.lineWidth = 4
    @context.strokeStyle = 'black'

  clear: =>
    @context.fillStyle = 'white'
    @context.fillRect 0, 0, @context.canvas.width, @context.canvas.height

  draw_line: (start, end) =>
    do @context.beginPath
    @context.moveTo start.x, start.y
    @context.lineTo end.x, end.y
    do @context.stroke
    do @context.closePath
