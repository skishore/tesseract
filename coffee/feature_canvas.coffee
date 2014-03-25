class @FeatureCanvas extends Canvas
  constructor: (elt) ->
    super elt
    @fill 'white'
    window.x = @

  copy_from: (other) =>
    @fill 'white'
    super other

  @get_pixel: (pixels, x, y) ->
    offset = 4*(x + pixels.width*y)
    (pixels.data[offset + i] for i in [0...4])

  @set_pixel: (pixels, x, y, result) ->
    offset = 4*(x + pixels.width*y)
    for i in [0...4]
      pixels.data[offset + i] = result[i]

  @convolve: (pixels, weights, offset) =>
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
        @set_pixel result, i, j, [r, g, b, 255]
    result

  get_pixels: =>
    @context.getImageData 0, 0, @context.canvas.width, @context.canvas.height

  set_pixels: (pixels) =>
    destination = do @get_pixels
    for i in [0...pixels.data.length]
      destination.data[i] = (Math.min (Math.max pixels.data[i], 0), 255)
    @context.putImageData destination, 0, 0
