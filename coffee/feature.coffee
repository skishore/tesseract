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

  constructor: (@elt, @other) ->
    super @elt
    if @other.mouse.touch_enabled
      @context.canvas.width = @context.canvas.width/2
      @context.canvas.height = @context.canvas.height/2
      do @set_line_style
      @context.lineWidth = 1
    else
      @context.lineWidth = 2
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

  get_angles: (stroke) =>
    if stroke.length < 2
      return []
    result = []
    last_angle = undefined
    angle = @get_angle stroke[0], stroke[1]
    for i in [1...stroke.length - 1]
      [last_angle, angle] = [angle, @get_angle stroke[i], stroke[i + 1]]
      result.push (angle - last_angle + 3*Math.PI) % (2*Math.PI) - Math.PI
    result

  get_angle_color: (angle) ->
    if not angle
      return 'black'
    k = 10
    color = new $.Color k*255*angle/Math.PI, -k*255*angle/Math.PI, 0
    do color.toString

  smooth_angles: (angles) =>
    result = []
    for i in [0...angles.length]
      points = [angles[i]]
      if i > 0
        points.push angles[i - 1]
      if i < angles.length - 1
        points.push angles[i + 1]
      result.push (@sum points)/points.length
    result

  viterbi: (angles) =>
    angles = @smooth_angles angles
    threshold = 0.01*Math.PI
    sharp_threshold = 0.1*Math.PI
    states = {
      # TODO(skishore): Why don't these probabilities add up to 1?
      0: (angle) -> if angle > threshold then 0.8 else if angle > -sharp_threshold then 0.1 else 0.001
      1: (angle) -> if Math.abs(angle) > threshold then 0.05 else 0.9
      2: (angle) -> if angle < -threshold then 0.8 else if angle < sharp_threshold then 0.1 else 0.001
    }
    transition_prob = 0.01
    memo = [{0: [0, undefined], 1: [0, undefined], 2: [0, undefined]}]
    for angle in angles
      new_memo = {}
      for state of states
        [best_log, best_state] = [-Infinity, undefined]
        for last_state of states
          [last_log, _] = memo[memo.length - 1][last_state]
          new_log = last_log + ( \
              if last_state == state then 0 else Math.log transition_prob)
          if new_log > best_log
            [best_log, best_state] = [new_log, last_state]
        penalty = Math.log states[state] angle
        new_memo[state] = [best_log + penalty, best_state]
      memo.push new_memo
    [best_log, best_state] = [-Infinity, undefined]
    for state of states
      [log, _] = memo[memo.length - 1][state]
      if log > best_log
        [best_log, best_state] = [log, state]
    result = [state]
    for i in [memo.length - 1...1]
      state = memo[i][state][1]
      result.push state
    do result.reverse
    result

  get_state_color: (state) =>
    {0: '#C00', 1: '#000', 2: '#080'}[state]

  stretch: (k, bounds) =>
    [min, max] = bounds
    return [
      {x: min.x - k*(max.x - min.x), y: min.y - k*(max.y - min.y)},
      {x: max.x + k*(max.x - min.x), y: max.y + k*(max.y - min.y)},
    ]

  run_viterbi: (other) =>
    bounds = @stretch 0.1, @get_bounds [].concat.apply [], other.strokes
    strokes = ( \
      (@rescale bounds, point for point in stroke) \
      for stroke in other.strokes
    )
    for stroke in strokes
      if stroke.length < 3
        continue
      stroke = @smooth @smooth @smooth stroke
      angles = @get_angles stroke
      states = @viterbi angles
      for i in [1...stroke.length - 1]
        [last_state, state] = [state, states[i - 1]]
        @context.strokeStyle = @get_state_color state
        @draw_line stroke[i], stroke[i + 1]
        # Draw a circle to mark state transitions.
        if state != last_state
          [old_width, @context.lineWidth] = [@context.lineWidth, 4]
          @context.strokeStyle = @get_state_color state
          @draw_point stroke[i]
          @context.lineWidth = old_width

  distance: (point1, point2) =>
    [dx, dy] = [point2.x - point1.x, point2.y - point1.y]
    return Math.sqrt dx*dx + dy*dy

  shrink_loop: (stroke, i, j) =>
    original_i = i
    while true
      best_distance = Infinity
      for di in [0, 1]
        if i + di >= stroke.length
          continue
        for dj in [-1, 0, 1]
          if j + dj <= di or i + j + dj >= stroke.length
            continue
          distance = @distance stroke[i + di], stroke[i + j + dj]
          if distance < best_distance
            best_distance = distance
            [best_di, best_dj] = [di, dj]
      if best_di == 0 and best_dj == 0
        break
      [i, j] = [i + best_di, j + best_dj - best_di]
    return [i, j]

  draw_loops: (stroke) =>
    n = 40
    [max_k, min_k] = [0.5, 0.1]
    i = 0
    # Get a list of states. We will only find loops among consecutive
    # points in the stroke with the same state.
    states = @viterbi @get_angles stroke
    states.unshift states[0]
    states.push states[states.length - 1]
    while i < stroke.length - 1
      max_distance = -Infinity
      found_loop = false
      for j in [1...n]
        if (i + j >= stroke.length) or (states[i + j] != states[i])
          break
        distance = @distance stroke[i], stroke[i + j]
        max_distance = Math.max distance, max_distance
        if distance < (j*min_k + (n - j)*max_k)*max_distance/n
          found_loop = true
          [i, j] = @shrink_loop stroke, i, j
          @context.strokeStyle = '#000'
          @draw_line stroke[i], stroke[i + j]
          next_i = i + j
          while i < next_i
            @context.strokeStyle = '#00C'
            @draw_line stroke[i], stroke[i + 1]
            i += 1
          break
      if not found_loop
        i += 1

  find_loops: (other) =>
    bounds = @stretch 0.1, @get_bounds [].concat.apply [], other.strokes
    strokes = ( \
      (@rescale bounds, point for point in stroke) \
      for stroke in other.strokes
    )
    for stroke in strokes
      if stroke.length > 2
        stroke = @smooth @smooth @smooth stroke
        @draw_loops stroke

  run: =>
    @fill 'white'
    @run_viterbi @other
    @find_loops @other
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
