class @FeatureCanvas extends Canvas
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

  constructor: (elt) ->
    super elt
    @fill 'white'
    elt.height 2*do elt.height
    elt.width 2*do elt.width

  copy_from: (other) =>
    @fill 'white'
    super other

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

  get_gradient: (offset) =>
    pixels = do @get_pixels
    [
      (@convolve pixels, [-1, 0, 1, -2, 0, 2, -1, 0, 1], offset),
      (@convolve pixels, [-1, -2, -1, 0, 0, 0, 1, 2, 1], offset),
    ]

  sobel: =>
    [gradx, grady] = @get_gradient 128
    for i in [0...gradx.data.length] by 4
      gradx.data[i + 1] = grady.data[i]
      gradx.data[i + 2] = (gradx.data[i] + grady.data[i])/4
    gradx

  corner: =>
    [gradx, grady] = do @get_gradient
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
    data = (@blur psd_pixels, 3).data
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

  run: =>
    @set_pixels do @corner

  get_pixels: =>
    @context.getImageData 0, 0, @context.canvas.width, @context.canvas.height

  set_pixels: (pixels) =>
    destination = do @get_pixels
    for i in [0...pixels.data.length]
      destination.data[i] = (Math.min (Math.max pixels.data[i], 0), 255)
    for i in [0...pixels.data.length] by 4
      destination.data[i + 3] = 255
    @context.putImageData destination, 0, 0
