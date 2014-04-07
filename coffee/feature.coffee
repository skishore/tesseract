class Util
  @angle: (point1, point2) ->
    # Returns the angle of the line formed between two points.
    Math.atan2 point2.y - point1.y, point2.x - point1.x

  @angles: (stroke) ->
    # Takes an n-point stroke of n elements and returns an (n - 2)-element
    # list of angles between adjacent points. This method will throw an error
    # if the stroke has <= 2 points.
    result = []
    last_angle = undefined
    angle = Util.angle stroke[0], stroke[1]
    for i in [1...stroke.length - 1]
      [last_angle, angle] = [angle, Util.angle stroke[i], stroke[i + 1]]
      result.push (angle - last_angle + 3*Math.PI) % (2*Math.PI) - Math.PI
    result

  @bounds: (stroke) ->
    # Returns a [min, max] pair of corners of a box bounding the points.
    x_values = (point.x for point in stroke)
    y_values = (point.y for point in stroke)
    return [
      {x: (Math.min.apply 0, x_values), y: (Math.min.apply 0, y_values)},
      {x: (Math.max.apply 0, x_values), y: (Math.max.apply 0, y_values)},
    ]

  @distance: (point1, point2) ->
    # Return the Euclidean distance between two points.
    [dx, dy] = [point2.x - point1.x, point2.y - point1.y]
    return Math.sqrt dx*dx + dy*dy

  @intersection: (s1, t1, s2, t2) ->
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

  @rescale: (bounds, point) ->
    # Takes a list of points within the given bounds, and rescales them so that
    # the points are bounded within the unit square.
    [min, max] = bounds
    x: (point.x - min.x)/(max.x - min.x)
    y: (point.y - min.y)/(max.y - min.y)

  @smooth: (values, iterations) ->
    # Runs a number of smoothing iterations on the list. In each iteration,
    # each value in the list is averaged with its neightbors.
    for i in [0...iterations]
      result = []
      for i in [0...values.length]
        samples = ( \
          values[i + j] for j in [-1..1] \
          when 0 <= i + j < values.length
        )
        result.push (Util.sum samples)/samples.length
      values = result
    values

  @smooth_stroke: (stroke, iterations) ->
    # Smooths the list of points coordinate-by-coordinate.
    x_values = Util.smooth (point.x for point in stroke), iterations
    y_values = Util.smooth (point.y for point in stroke), iterations
    return ({x: x_values[i], y: y_values[i]} for i in [0...stroke.length])

  @sum: (values) ->
    # Return the sum of elements in the list.
    total = 0
    for value in values
      total += value
    total


class Segment
  length_threshold: 0.4

  constructor: (@stroke, @state, i, j, closed) ->
    @reset i, j, closed

  reset: (@i, @j, closed) =>
    @bounds = Util.bounds @stroke.slice i, j
    @length = if i >= j then 0 else
        Util.sum (Util.distance @stroke[k], @stroke[k + 1] for k in [i...j - 1])
    @closed = if closed then true else false
    # Compute signals for this segment.
    @minor = @length < @length_threshold
    @color = do @get_color

  draw: (canvas) =>
    canvas.line_width = 1
    if not @minor
      canvas.draw_rect @bounds[0], @bounds[1]
      canvas.line_width = 2
    canvas.context.strokeStyle = @color
    for k in [@i...@j]
      #canvas.draw_point @stroke[k]
      if k + 1 < @j
        canvas.draw_line @stroke[k], @stroke[k + 1]

  get_color: =>
    if @closed
      return {1: '#808', 2: '#00C'}[@state]
    return {0: '#000', 1: '#C00', 2: '#080'}[@state]

  merge: (other) =>
    if @j != other.i then console.log 'Unexpected merge!'
    @reset @i, other.j, @closed or other.closed

  serialize: =>
    start: @stroke[@i]
    end: @stroke[@j - 1]
    count: @j - @i
    bounds: @bounds
    length: @length
    closed: @closed
    state: @state


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
      magnitude = Math.abs angle
      if magnitude < threshold then 0.9
      else if magnitude < sharp_threshold then 0.05 else 0.001
    1: (angle) ->
      if angle > threshold then 0.8
      else if angle > -sharp_threshold then 0.1 else 0.001
    2: (angle) ->
      if angle < -threshold then 0.8
      else if angle < sharp_threshold then 0.1 else 0.001
  }
  transition_prob: 0.01

  # The maximum number of stroke points in a loop.
  loop_count: 80
  # How tolerant we are of unclosed loops at stroke endpoints. Set this
  # constant to 0 to ensure that all loops are complete.
  loop_tolerance: 0.25

  # The maximum number of points and length of a hook.
  hook_count: 10
  hook_length: 0.1

  # Thresholds controlling stroke segmentation during preprocessing.
  merge_threshold: 1.0
  split_threshold: 0.5

  constructor: (bounds, stroke) ->
    stroke = Util.smooth_stroke stroke, @stroke_smoothing
    @stroke = (Util.rescale bounds, point for point in stroke)
    if @stroke.length > 2
      states = @viterbi Util.angles @stroke
      @states = @postprocess @stroke, states
      @loops = @find_loops @stroke, @states
    else
      @states = (0 for point in @stroke)
      @loops = []
    @segments = @segment @stroke, @states, @loops

  draw: (canvas) =>
    for segment in @segments
      segment.draw canvas
    for [i, j] in @loops
      for k in [i...j - 1]
        canvas.context.strokeStyle = '#00C'
        #canvas.draw_line @stroke[k], @stroke[k + 1]

  find_loops: (stroke, states) =>
    loops = []
    i = 0
    while i < stroke.length
      for j in [3...@loop_count]
        if i + j + 1 >= stroke.length
          break
        [u, v, point] = @find_stroke_intersection stroke, i, i + j - 1
        if point and 0 <= u < 1 and 0 <= v < 1
            loops.push [i, i + j + 1]
            i += j
      i += 1
    @find_loose_loops stroke, states, loops

  find_loose_loops: (stroke, states, loops) =>
    for i in [0, stroke.length - 2]
      states_found = {}
      dir = if i == 0 then 1 else -1
      j = i + 3*dir
      if loops.length
        bound = if i == 0 then loops[0][0] else loops[loops.length - 1][1] - 1
      else
        bound = if i == 0 then stroke.length else 0
      while dir*j < dir*bound
        # Loose loops are not allowed to contain both cw and ccw segments.
        states_found[states[j]] = true
        if states_found[1] and states_found[2]
          break
        [u, v, point] = @find_stroke_intersection stroke, i, j - 1
        # Add a special case for a loop that contains the entire stroke.
        skip_v = j == stroke.length - 2 and v > 1
        if point and dir*u < (dir - 1)/2 and (0 <= v < 1 or skip_v) and
            (Util.distance stroke[i], point) < @loop_tolerance
          if i == 0 then loops.unshift [i, j + 1] else loops.push [j - 1, i + 2]
          break
        j += dir
    loops

  find_stroke_intersection: (stroke, i, j) =>
    Util.intersection stroke[i], stroke[i + 1], stroke[j], stroke[j + 1]

  postprocess: (stroke, states) =>
    # Takes an (n - 2)-element list of states and extends it to a list of n
    # states, one for each stroke point. Also does some final cleanup.
    states.unshift states[0]
    states.push states[states.length - 1]
    @remove_hooks stroke, states

  remove_hooks: (stroke, states) =>
    size = stroke.length
    if size > @hook_count
      # Remove hooks at the beginning of the stroke.
      for i in [0...@hook_count]
        if (Util.distance stroke[0], stroke[i]) > @hook_length
          break
      for j in [0...i]
        states[j] = states[i]
      # Remove hooks at the end of the stroke.
      for i in [size - 1..size - @hook_count]
        if (Util.distance stroke[size - 1], stroke[i]) > @hook_length
          break
      for j in [size - 1...i]
        states[j] = states[i]
    states

  segment: (stroke, states, loops) =>
    # Returns a list of segments that (almost) partition the stroke.
    segments = @segment_states stroke, states
    segments = @merge_straight_segments segments, stroke, states
    segments = @split_loop_segments segments, stroke, states, loops
    segments

  segment_states: (stroke, states) =>
    # Returns the list of segments based on on state data.
    result = []
    for state, i in states
      if result.length and state == states[result[result.length - 1][0]]
        result[result.length - 1][1] = i + 1
      else
        result.push [i, i + 1]
    (new Segment stroke, states[i], i, j for [i, j] in result)

  merge_straight_segments: (segments, stroke, states) =>
    result = []
    i = 0
    while i < segments.length
      segment = segments[i]
      if result.length and i < segments.length - 1
        [prev, next] = [result[result.length - 1], segments[i + 1]]
        if segment.state == 0 and prev.state == next.state != 0
          if segment.length < @merge_threshold*(prev.length + next.length)
            prev.merge segment
            prev.merge next
            i += 2
            continue
      result.push segment
      i += 1
    result

  split_loop_segments: (segments, stroke, states, loops) =>
    result = []
    dominates = (segment1, segment2) =>
      segment1.closed and not segment2.closed and
      (segment2.state == 0 or segment2.state == segment1.state) and
      segment2.length < @split_threshold*segment1.length
    push_segment = (segment) ->
      if result.length and dominates result[result.length - 1], segment
        result[result.length - 1].merge segment
      else
        result.push segment
    [i, j] = [0, 0]
    while i < segments.length and j < loops.length
      [min, max] = loops[j]
      while segments[i].j < min
        push_segment segments[i]
        i += 1
      # Get the list of segments that overlap loop `dot`.
      overlaps = []
      while segments[i].j < max
        overlaps.push segments[i]
        i += 1
      overlaps.push segments[i]
      # Check if this loop is a clockwise or counterclockwise loop.
      state_1_minus_state_2 = 0
      for overlap in overlaps
        if overlap.state
          count = (Math.min max, overlap.j) - (Math.max min, overlap.i)
          state_1_minus_state_2 += if overlap.state == 1 then count else -count
      state = if state_1_minus_state_2 > 0 then 1 else 2
      # Construct a list of three segments that will be used to cover the loop.
      [before, after] = [overlaps[0], overlaps[overlaps.length - 1]]
      prev_segment = new Segment stroke, before.state, before.i, min
      loop_segment = new Segment stroke, state, min, max, true
      if dominates loop_segment, prev_segment
        prev_segment.state = loop_segment.state
        prev_segment.merge loop_segment
        push_segment prev_segment
      else
        push_segment prev_segment
        push_segment loop_segment
      if after.j > max
        segments[i] = new Segment stroke, after.state, max, after.j
      else
        i += 1
      j += 1
    while i < segments.length
      push_segment segments[i]
      i += 1
    result

  viterbi: (angles) =>
    # Finds the maximum-likelihood state list of an HMM for the list of angles.
    angles = Util.smooth angles, @angle_smoothing
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
    result = [parseInt state]
    for i in [memo.length - 1...1]
      state = memo[i][state][1]
      result.push parseInt state
    do result.reverse
    result

  serialize: =>
    (do segment.serialize for segment in @segments)


class @Feature extends Canvas
  border: 0.1
  line_width: 1
  point_width: 4

  constructor: (@elt) ->
    parent = do elt.parent
    parent.find('.test, .train').width (do parent.width - do @elt.width)/2 - 1
    super @elt
    window.feature = @

  draw_line: (point1, point2) =>
    @context.lineWidth = @line_width
    super (@rescale point1), (@rescale point2)

  draw_point: (point, color) =>
    @context.lineWidth = @point_width
    super @rescale point

  draw_rect: (point1, point2) =>
    @context.lineWidth = @line_width
    @context.setLineDash [1, 2]
    @context.strokeStyle = 'black'
    super (@rescale point1), (@rescale point2)
    @context.setLineDash []

  redraw: (data) =>
    @run data or []
    @fill 'white'
    for stroke in @strokes
      stroke.draw @

  rescale: (point) =>
    x: ((1 - 2*@border)*point.x + @border)*@context.canvas.width
    y: ((1 - 2*@border)*point.y + @border)*@context.canvas.height

  run: (data) =>
    @data = data.slice 0
    bounds = Util.bounds [].concat.apply [], data
    @strokes = (new Stroke bounds, stroke for stroke in data)

  serialize: =>
    data: @data
    strokes: (do stroke.serialize for stroke in @strokes)
