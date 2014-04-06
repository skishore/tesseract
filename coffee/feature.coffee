# TODO: Instead of adding tolerance for endpoint loops in the main loop-
# finding code, we should have a separate endpoint loop finding code that
# works as follows: it starts at the first point and looks for near-closed
# loops, but it stops at a color change or an already detected loop.


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

  # The maximum number of stroke points in a loop.
  loop_length: 80
  # How tolerant we are of unclosed loops at stroke endpoints. Set this
  # constant to 0 to ensure that all loops are complete.
  loop_tolerance: 0.25

  constructor: (bounds, stroke) ->
    stroke = @smooth_stroke stroke, @stroke_smoothing
    @stroke = (@rescale bounds, point for point in stroke)
    if stroke.length > 2
      states = @viterbi @get_angles @stroke
      @states = @postprocess states
    else
      @states = (0 for point in stroke)

  @get_bounds: (stroke) ->
    # Returns a [min, max] pair of corners of a box bounding the points.
    x_values = (point.x for point in stroke)
    y_values = (point.y for point in stroke)
    return [
      {x: (Math.min.apply 0, x_values), y: (Math.min.apply 0, y_values)},
      {x: (Math.max.apply 0, x_values), y: (Math.max.apply 0, y_values)},
    ]

  distance: (point1, point2) =>
    # Return the Euclidean distance between two points.
    [dx, dy] = [point2.x - point1.x, point2.y - point1.y]
    return Math.sqrt dx*dx + dy*dy

  draw: (canvas) =>
    for i in [0...@stroke.length]
      [last_state, state] = [state, @states[i]]
      if state == last_state
        canvas.context.strokeStyle = @get_state_color state
        canvas.draw_line @stroke[i - 1], @stroke[i]
    @draw_loops @stroke, canvas

  draw_loops: (stroke, canvas) =>
    i = 0
    while i < stroke.length
      for j in [3...@loop_length]
        if i + j + 1 >= stroke.length
          break
        [u, v, point] = @find_stroke_intersection stroke, i, i + j - 1
        if point
          skip_u = (
            i == 0 and u < 0 and
            (@distance stroke[i], point) < @loop_tolerance
          )
          skip_v = (
            i + j + 2 == stroke.length and v > 1 and
            (@distance stroke[i + j + 1], point) < @loop_tolerance
          )
          if (0 <= u < 1 or skip_u) and (0 <= v < 1 or skip_v)
            canvas.context.strokeStyle = '#00F'
            for k in [i...i + j]
              canvas.draw_line stroke[k], stroke[k + 1]
            i += j + 1
      i += 1

  find_intersection: (s1, t1, s2, t2) =>
    # Finds the intersection between rays s1 -> t1 and s2 -> t2, where the
    # ray a -> b is the ray that begins at a and passes through b.
    #
    # Returns a list [u, v, point], where point is the intersection point
    # and u and v are the fraction of the distance along ray1 and ray2 that
    # the point occurs. Return [und, und, und] if no intersection can be found.
    d1 = {x: t1.x - s1.x, y: t1.y - s1.y}
    d2 = {x: t2.x - s2.x, y: t2.y - s2.y}
    [dx, dy] = [s2.x - s1.x, s2.y - s1.y]
    det = (d1.x*d2.y - d1.y*d2.x)
    if not det
      # Handle degenerate cases where we may still have an intersection.
      # If ray1 has positive length and ray2's start occurs on it, we will
      # return a valid intersection.
      big = (x) -> (Math.abs x) > 0.001
      if ((big d1.x) or (big d1.y)) and not big dx*d1.y - dy*d1.x
        dim = if big d1.x then 'x' else 'y'
        u = (s2[dim] - s1[dim])/d1[dim]
        return [u, 0, s2]
      return [undefined, undefined, undefined]
    u = (dx*d2.y - dy*d2.x)/det
    v = (dx*d1.y - dy*d1.x)/det
    [u, v, {x: s1.x + d1.x*u, y: s1.y + d1.y*u}]

  find_stroke_intersection: (stroke, i, j) =>
    @find_intersection stroke[i], stroke[i + 1], stroke[j], stroke[j + 1]

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
  line_width: 1
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

  run: =>
    @fill 'white'
    strokes = @other.strokes
    bounds = Stroke.get_bounds [].concat.apply [], strokes
    strokes = (new Stroke bounds, stroke for stroke in strokes)
    for stroke in strokes
      stroke.draw @
