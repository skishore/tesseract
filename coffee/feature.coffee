class Stroke
  # The initial number of smoothing iterations applied to the stroke.
  stroke_smoothing: 3

  # Constants that control the hidden Markov model used to decompose strokes.
  # State 0 -> straight, state 1 -> clockwise, state 2 -> counterclockwise.
  angle_smoothing: 1
  threshold = 0.01*Math.PI
  sharp_threshold = 0.1*Math.PI
  pdfs: {
    0: (angle) ->
      if Math.abs(angle) > threshold then 0.05 else 0.9
    1: (angle) ->
      if angle > threshold then 0.8
      else if angle > -sharp_threshold then 0.1 else 0.001
    2: (angle) ->
      if angle < -threshold then 0.8
      else if angle < sharp_threshold then 0.1 else 0.001
  }
  transition_prob: 0.01

  constructor: (bounds, stroke) ->
    stroke = @smooth_stroke stroke, @stroke_smoothing
    @stroke = (@rescale bounds, point for point in stroke)
    if stroke.length > 2
      states = @viterbi @get_angles @stroke
      @states = @postprocess states
    else
      @states = (0 for point in strokes)

  @get_bounds: (stroke) ->
    # Returns a [min, max] pair of corners of a box bounding the points.
    x_values = (point.x for point in stroke)
    y_values = (point.y for point in stroke)
    return [
      {x: (Math.min.apply 0, x_values), y: (Math.min.apply 0, y_values)},
      {x: (Math.max.apply 0, x_values), y: (Math.max.apply 0, y_values)},
    ]

  draw: (canvas) =>
    for i in [0...@stroke.length]
      [last_state, state] = [state, @states[i]]
      if state == last_state
        canvas.context.strokeStyle = @get_state_color state
        canvas.draw_line @stroke[i - 1], @stroke[i]

  get_angle: (point1, point2) =>
    # Returns the angle of the line formed between two points.
    Math.atan2 point2.y - point1.y, point2.x - point1.x

  get_angles: (stroke) =>
    # Takes an n-point stroke of n elements and returns an (n - 2)-element
    # list of angles between adjacent points. This method will throw an error
    # if the stroke has <= 2 points.
    result = []
    last_angle = undefined
    angle = @get_angle stroke[0], stroke[1]
    for i in [1...stroke.length - 1]
      [last_angle, angle] = [angle, @get_angle stroke[i], stroke[i + 1]]
      result.push (angle - last_angle + 3*Math.PI) % (2*Math.PI) - Math.PI
    result

  get_state_color: (state) =>
    {0: '#000', 1: '#C00', 2: '#080'}[state]

  postprocess: (states) =>
    # Takes an (n - 2)-element list of states and extends it to a list of n
    # states, one for each stroke point. Also does some final cleanup.
    states.unshift states[0]
    states.push states[states.length - 1]
    states

  rescale: (bounds, point) =>
    # Takes a list of points within the given bounds, and rescales them so that
    # the points are bounded within the unit square.
    [min, max] = bounds
    x: (point.x - min.x)/(max.x - min.x)
    y: (point.y - min.y)/(max.y - min.y)

  smooth: (values, iterations) =>
    # Runs a number of smoothing iterations on the list. In each iteration,
    # each value in the list is averaged with its neightbors.
    for i in [0...iterations]
      result = []
      for i in [0...values.length]
        samples = ( \
          values[i + j] for j in [-1..1] \
          when 0 <= i + j < values.length
        )
        result.push (@sum samples)/samples.length
      values = result
    values

  smooth_stroke: (stroke, iterations) =>
    # Smooths the list of points coordinate-by-coordinate.
    x_values = @smooth (point.x for point in stroke), iterations
    y_values = @smooth (point.y for point in stroke), iterations
    return ({x: x_values[i], y: y_values[i]} for i in [0...stroke.length])

  sum: (values) ->
    # Return the sum of elements in the list.
    total = 0
    for value in values
      total += value
    total

  viterbi: (angles) =>
    # Finds the maximum-likelihood state list of an HMM for the list of angles.
    angles = @smooth angles, @angle_smoothing
    # Build a memo, where memo[i][state] is a pair [best_log, last_state],
    # where best_log is the greatest possible log probability assigned to
    # any chain that ends at state `state` at index i, and last_state is the
    # state at index i - 1 for that chain.
    memo = [{0: [0, undefined], 1: [0, undefined], 2: [0, undefined]}]
    for angle in angles
      new_memo = {}
      for state of @pdfs
        [best_log, best_state] = [-Infinity, undefined]
        for last_state of @pdfs
          [last_log, _] = memo[memo.length - 1][last_state]
          new_log = last_log + ( \
              if last_state == state then 0 else Math.log @transition_prob)
          if new_log > best_log
            [best_log, best_state] = [new_log, last_state]
        penalty = Math.log @pdfs[state] angle
        new_memo[state] = [best_log + penalty, best_state]
      memo.push new_memo
    [best_log, best_state] = [-Infinity, undefined]
    # Trace back through the DP memo to recover the MLE state chain.
    for state of @pdfs
      [log, _] = memo[memo.length - 1][state]
      if log > best_log
        [best_log, best_state] = [log, state]
    result = [state]
    for i in [memo.length - 1...1]
      state = memo[i][state][1]
      result.push state
    do result.reverse
    result


class @Feature extends Canvas
  border: 0.1
  line_width: 2
  point_width: 4

  constructor: (@elt, @other) ->
    super @elt
    window.feature = @
    window.Stroke = Stroke
    do @run

  rescale: (point) =>
    x: ((1 - 2*@border)*point.x + @border)*@context.canvas.width
    y: ((1 - 2*@border)*point.y + @border)*@context.canvas.height

  draw_line: (point1, point2, color) =>
    @context.lineWidth = @line_width
    super (@rescale point1), (@rescale point2)

  draw_point: (point, color) =>
    @context.lineWidth = @point_width
    super @rescale point

  run_viterbi: (other) =>
    bounds = Stroke.get_bounds [].concat.apply [], other.strokes
    strokes = (new Stroke bounds, stroke for stroke in other.strokes)
    for stroke in strokes
      stroke.draw @

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
    #@find_loops @other
