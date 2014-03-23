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
    @context.lineWidth = Math.ceil 0.02*@context.canvas.width
    @context.strokeStyle = 'black'

  clear: =>
    @context.clearRect 0, 0, @context.canvas.width, @context.canvas.height

  fill: (fill_style) =>
    @context.fillStyle = fill_style
    @context.fillRect 0, 0, @context.canvas.width, @context.canvas.height

  copy_from: (other) =>
    canvas = @context.canvas
    @context.drawImage other.context.canvas, 0, 0, canvas.width, canvas.height

  draw_line: (start, end) =>
    do @context.beginPath
    @context.moveTo start.x, start.y
    @context.lineTo end.x, end.y
    do @context.stroke
    do @context.closePath

  get_base64_image: =>
    do @context.canvas.toDataURL
