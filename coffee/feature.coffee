class @Feature extends Canvas
  gauss2: [
    7, 5,
    3, 1,
  ]
  gauss3: [
    1, 2, 1,
    2, 4, 2,
    1, 2, 1,
  ]
  gauss5: [
     2,   7,  12,   7,  2,
     7,  31,  52,  31,  7,
    12,  52, 127,  52, 12,
     7,  31,  52,  31,  7,
     2,   7,  12,   7,  2,
  ]

  constructor: (elt, @other) ->
    super elt
    @context.lineWidth = 2
    #elt.height 2*do elt.height
    #elt.width 2*do elt.width
    window.feature = @
    do @run

  get_pixel: (pixels, x, y) ->
    offset = 4*(x + pixels.width*y)
    (pixels.data[offset + i] for i in [0...4])

  set_pixel: (pixels, x, y, result) ->
    offset = 4*(x + pixels.width*y)
    for i in [0...4]
      pixels.data[offset + i] = result[i]

  convolve: (pixels, weights, offset) =>
    side = Math.round Math.sqrt weights.length
    half = Math.floor side/2
    offset = offset or 0
    result =
      width: pixels.width
      height: pixels.height
      data: new Array pixels.data.length
    for i in [0...pixels.width]
      for j in [0...pixels.height]
        [r, g, b, a] = [offset, offset, offset, offset]
        for di in [0...side]
          for dj in [0...side]
            [x, y] = [i + di - half, j + dj - half]
            if x >= 0 and x < pixels.width and y >= 0 and y < pixels.height
              [dr, dg, db, da] = @get_pixel pixels, i + di - half, j + dj - half
              weight = weights[di + side*dj]
              r += dr*weight
              g += dg*weight
              b += db*weight
              a += da*weight
        @set_pixel result, i, j, [r, g, b, a]
    result

  blur: (pixels, radius, offset) =>
    if radius == 1
      return pixels
    weights = @['gauss' + radius]
    sum = 0
    for weight in weights
      sum += weight
    weights = (weight/sum for weight in weights)
    @convolve pixels, weights, offset

  get_gradient: (pixels, offset) =>
    [
      (@convolve pixels, [-1, 0, 1, -2, 0, 2, -1, 0, 1], offset),
      (@convolve pixels, [-1, -2, -1, 0, 0, 0, 1, 2, 1], offset),
    ]

  sobel: (pixels) =>
    [gradx, grady] = @get_gradient pixels, 128
    for i in [0...gradx.data.length] by 4
      gradx.data[i + 1] = grady.data[i]
      gradx.data[i + 2] = (gradx.data[i] + grady.data[i])/4
    gradx

  corner: (pixels) =>
    [gradx, grady] = @get_gradient pixels
    psd = new Array gradx.data.length
    for i in [0...gradx.data.length] by 4
      [ix, iy] = [gradx.data[i]/256, grady.data[i]/256]
      # Compute a PSD matrix which represents the bilinear form that measures
      # how fast the intensity of the image changes in any given direction.
      psd[i] = ix*ix
      psd[i + 1] = psd[i + 2] = ix*iy
      psd[i + 3] = iy*iy
    # Pack the matrices into a pixel buffer and apply a Gaussian blur to them.
    psd_pixels = {width: gradx.width, height: gradx.height, data: psd}
    data = (@blur psd_pixels, 2).data
    # Compute the eigenvalue of the blurred matrix at each point.
    for i in [0...gradx.data.length] by 4
      trace = data[i] + data[i + 3]
      det = data[i]*data[i + 3] - data[i + 1]*data[i + 2]
      radicand = Math.sqrt(trace*trace - 4*det)
      roots = [(radicand + trace)/2, (-radicand + trace)/2]
      # We can reuse this buffer because we're returning after this loop.
      [data[i], data[i + 1], data[i + 2], data[i + 3]] = \
          [8*roots[0], 64*roots[1], 0, 255]
    data: data

  get_bounds: (points) ->
    x_values = (point.x for point in points)
    y_values = (point.y for point in points)
    return [
      {x: (Math.min.apply 0, x_values), y: (Math.min.apply 0, y_values)},
      {x: (Math.max.apply 0, x_values), y: (Math.max.apply 0, y_values)},
    ]

  rescale: (bounds, point) =>
    [min, max] = bounds
    x: @context.canvas.width*(point.x - min.x)/(max.x - min.x)
    y: @context.canvas.height*(point.y - min.y)/(max.y - min.y)

  sum: (values) =>
    total = 0
    for value in values
      total += value
    total

  smooth: (stroke) =>
    result = []
    for i in [0...stroke.length]
      points = [stroke[i]]
      if i > 0
        points.push stroke[i - 1]
      if i < stroke.length - 1
        points.push stroke[i + 1]
      x_values = (point.x for point in points)
      y_values = (point.y for point in points)
      result.push
        x: (@sum x_values)/points.length
        y: (@sum y_values)/points.length
    result

  get_angle: (point1, point2) =>
    Math.atan2 point2.y - point1.y, point2.x - point1.x

  get_angle_color: (angle) ->
    k = 10
    angle = (angle + 3*Math.PI) % (2*Math.PI) - Math.PI
    color = new $.Color k*255*angle/Math.PI, -k*255*angle/Math.PI, 0
    do color.toString

  copy_strokes: (other, color, smooth) =>
    @context.strokeStyle = color
    bounds = @get_bounds [].concat.apply [], other.strokes
    strokes = ( \
      (@rescale bounds, point for point in stroke) \
      for stroke in other.strokes
    )
    for stroke in strokes
      if smooth
        stroke = @smooth stroke
      last_angle = undefined
      for i in [0...stroke.length - 1]
        [last_angle, angle] = [angle, @get_angle stroke[i], stroke[i + 1]]
        if i > 0
          @context.strokeStyle = @get_angle_color angle - last_angle
        @draw_line stroke[i], stroke[i + 1]

  run: =>
    @fill 'white'
    #@copy_strokes @other, 'red', false
    @copy_strokes @other, 'black', true
    #@copy_from @other
    #@set_pixels @corner do @get_pixels

  get_pixels: =>
    @context.getImageData 0, 0, @context.canvas.width, @context.canvas.height

  set_pixels: (pixels) =>
    destination = do @get_pixels
    for i in [0...pixels.data.length]
      destination.data[i] = (Math.min (Math.max pixels.data[i], 0), 255)
    for i in [0...pixels.data.length] by 4
      destination.data[i + 3] = 255
    @context.putImageData destination, 0, 0
