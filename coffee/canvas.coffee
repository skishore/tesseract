class @Canvas
  constructor: (@elt) ->
    @context = elt[0].getContext '2d'
    @context.canvas.height = do @elt.height
    @context.canvas.width = do @elt.width
    do @set_line_style
    @version = 0

  set_line_style: =>
    @context.lineCap = 'round'
    @context.lineJoin = 'round'
    @context.lineWidth = Math.ceil 0.018*@context.canvas.width
    @context.strokeStyle = 'black'

  clear: =>
    @context.clearRect 0, 0, @context.canvas.width, @context.canvas.height
    @version += 1

  fill: (fill_style) =>
    @context.fillStyle = fill_style
    @context.fillRect 0, 0, @context.canvas.width, @context.canvas.height
    @version += 1

  copy_from: (other) =>
    canvas = @context.canvas
    @context.drawImage other.context.canvas, 0, 0, canvas.width, canvas.height
    @version += 1

  draw_line: (start, end) =>
    do @context.beginPath
    @context.moveTo start.x, start.y
    @context.lineTo end.x, end.y
    do @context.stroke
    do @context.closePath
    @version += 1

  draw_point: (point) =>
    do @context.beginPath
    @context.arc point.x, point.y, 0.01, 0, 2*Math.PI
    do @context.stroke
    @version += 1

  get_base64_image: =>
    do @context.canvas.toDataURL
