class Segment
  length_threshold: 0.25

  constructor: (@stroke, @state, i, j, closed, dot) ->
    @reset i, j, closed, dot

  reset: (@i, @j, closed, dot) =>
    @bounds = Util.bounds @stroke.slice i, j
    @length = if i >= j then 0 else
        Util.sum (Util.distance @stroke[k], @stroke[k + 1] for k in [i...j - 1])
    # Compute signals for this segment. Minor segments on training data are
    # ignored by scoring, but can still be matched with major segments as test.
    @closed = if closed then true else false
    @dot = if dot then true else false
    @minor = @length < @length_threshold and not @dot
    @color = do @get_color

  draw: (canvas) =>
    if @dot
      canvas.context.strokeStyle = '#00F'
      canvas.draw_point
        x: (@bounds[0].x + @bounds[1].x)/2
        y: (@bounds[0].y + @bounds[1].y)/2
      return
    canvas.line_width = 1
    if not @minor
      canvas.draw_rect @bounds[0], @bounds[1]
      canvas.line_width = 2
    canvas.context.strokeStyle = @color
    for k in [@i...@j]
      if k + 1 < @j
        canvas.draw_line @stroke[k], @stroke[k + 1]

  get_color: =>
    if @closed
      return {1: '#808', 2: '#0AA'}[@state]
    return {0: '#000', 1: '#C00', 2: '#080'}[@state]

  merge: (other) =>
    if @j != other.i then console.log 'Unexpected merge!'
    @reset @i, other.j, @closed or other.closed

  serialize: =>
    bounds: @bounds
    count: @j - @i
    start: Util.rescale @bounds, @stroke[@i]
    end:  Util.rescale @bounds, @stroke[@j - 1]
    closed: @closed
    dot: @dot
    length: @length
    minor: @minor
    state: @state


class Point
  constructor: (points, @type) ->
    @x = (Util.sum (point.x for point in points))/points.length
    @y = (Util.sum (point.y for point in points))/points.length

  draw: (canvas) =>
    canvas.context.strokeStyle = '#000'
    k = 1
    canvas.point_width *= k
    canvas.draw_point @
    canvas.point_width /= k


class Stroke
  # The initial number of smoothing iterations applied to the stroke.
  stroke_smoothing: 3
  # Thresholds for marking a stroke as a dot.
  area_threshold: 0.01
  perimeter_threshold: 0.4

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
    bounds = Util.bounds @stroke
    if @stroke.length > 2 and @check_size bounds
      states = @viterbi Util.angles @stroke
      @states = @postprocess @stroke, states
      @loops = @find_loops @stroke, @states
      @segments = @segment @stroke, @states, @loops
    else
      @states = (0 for point in @stroke)
      @loops = []
      @segments = [new Segment @stroke, @states, 0, @stroke.length, true, true]
    @points = @find_points @stroke, @segments

  check_size: (bounds) =>
    # Return true if this stroke is big enough to not be considered a dot.
    (Util.area bounds[0], bounds[1]) > @area_threshold or
    (Util.perimeter bounds[0], bounds[1]) > @perimeter_threshold

  draw: (canvas) =>
    for segment in @segments
      segment.draw canvas
    for point in @points
      point.draw canvas

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

  find_points: (stroke, segments) =>
    if segments.length == 1 and (segments[0].dot or segments[0].closed)
      return @find_singleton_point segments[0]
    points = [
      (new Point [stroke[0]], 'endpoint'),
      (new Point [stroke[stroke.length - 1]], 'endpoint')
    ]
    for segment, i in segments
      if segment.closed
        type = if segment.minor then 'cusp' else 'loop'
        points.push new Point [@stroke[segment.i], @stroke[segment.j - 1]], type
      else if segment.minor
        if segment.state != 0
          left = i > 0 and segments[i - 1].state != segment.state
          right = i + 1 < segments.length and \
              segments[i + 1].state != segment.state
          [k, l] = [segment.i, segment.j]
          if left and right
            points.push new Point [@stroke[k], @stroke[l]], 'cusp'
          else if left
            points.push new Point [@stroke[k - 1], @stroke[k]], 'cusp'
          else if right
            points.push new Point [@stroke[l], @stroke[l + 1]], 'cusp'
      else if i > 0 and not segments[i - 1].minor and \
          segments[i - 1].state + segments[i].state == 3
        k = segments[i].i
        points.push new Point [@stroke[k - 1], @stroke[k]], 'inflection'
    points

  find_singleton_point: (segment) =>
    [new Point segment.bounds, if segment.dot then 'dot' else 'closed']

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
      return segment2.length == 0
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

  handle_180s: (angles) =>
    # If an angle is sufficiently close to 180 degrees, and if it is the same
    # sign as the two angles, flip its sign. This will cause our Markov model
    # detect a one time-step long state-change at the angle.
    #
    # For now, an angle is only close to 180 degrees if it equals +/-PI.
    for i in [1...angles.length - 1]
      if (Math.abs angles[i]) == Math.PI
        signs = ((Util.sign angles[j]) for j in [i - 1, i, i + 1])
        if signs[0] == signs[1] == signs[2]
          angles[i] *= -1
    angles

  viterbi: (angles) =>
    # Finds the maximum-likelihood state list of an HMM for the list of angles.
    #
    # Start by checking for any angle that are close enough to PI that they are
    # neither cw nor ccw. Then smooth the rest of the angles.
    angles = Util.smooth (@handle_180s angles), @angle_smoothing
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
