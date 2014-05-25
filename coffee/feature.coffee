class @LinearRegression
  constructor: (stroke) ->
    @n = 0
    @mean = x: 0, y: 0
    @variance = x: 0, y: 0
    @covariance = 0
    @add_stroke stroke

  add_point: (point) =>
    [dx, dy] = [point.x - @mean.x, point.y - @mean.y]
    @n += 1
    @mean.x += dx/@n
    @mean.y += dy/@n
    @variance.x += ((@n - 1)/@n*dx*dx - @variance.x)/@n
    @variance.y += ((@n - 1)/@n*dy*dy - @variance.y)/@n
    @covariance += ((@n - 1)/@n*dx*dy - @covariance)/@n

  add_stroke: (stroke) =>
    if stroke?.length
      for point in stroke
        @add_point point

  slope: =>
    @covariance/@variance.x

  intercept: =>
    @mean.y - (do @slope)/@mean.x

  correlation: =>
    if @variance.x == 0 or @variance.y == 0
      return 1
    @covariance/Math.sqrt @variance.x*@variance.y


class Segment
  length_threshold: 0.25

  constructor: (@stroke, @state, i, j, closed, dot) ->
    @reset i, j, closed, dot
    #if not (0 <= i < j <= @stroke.length)
    #  console.log 'Invalid segment!', @

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
    #if not @minor
    #  canvas.draw_rect @bounds[0], @bounds[1]
    #  canvas.line_width = 2
    canvas.context.strokeStyle = @color
    for k in [@i...@j]
      canvas.point_width /= 2
      canvas.draw_point @stroke[k]
      canvas.point_width *= 2
      #if k + 1 < @j
      #  canvas.draw_line @stroke[k], @stroke[k + 1]

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
    @color = '#000'

  draw: (canvas) =>
    canvas.context.strokeStyle = @color
    canvas.draw_point @


class Stroke
  # The initial number of smoothing iterations applied to the stroke.
  stroke_smoothing: 3
  # Thresholds for marking a stroke as a dot.
  area_threshold: 0.01
  perimeter_threshold: 0.4

  # Constants that control the hidden Markov model used to decompose strokes.
  #   state 1 -> clockwise, state 2 -> counterclockwise.
  angle_smoothing: 3
  curved_pdf = (angle) ->
    if angle > 0 then 1 else Math.exp -200*angle*angle
  pdfs: {
    1: curved_pdf
    2: (angle) -> curved_pdf -angle
  }
  curved_transition_prob: 0.000001

  # The maximum number of stroke points in a loop.
  loop_count: 80
  # How tolerant we are of unclosed loops at stroke endpoints. Set this
  # constant to 0 to ensure that all loops are complete.
  loop_tolerance: 0.2

  # The maximum number of points and length of a hook.
  hook_count: 10
  hook_length: 0.1

  # Thresholds controlling stroke segmentation during preprocessing.
  merge_threshold: 1.0
  split_threshold: 0.5

  drop_close_points: (stroke) =>
    result = []
    length = 0
    for point, i in stroke
      if i > 0
        length += Util.distance stroke[i - 1], point
      if result.length == 0 or length > 0.05
        result.push point
        length = 0
    result

  constructor: (bounds, stroke) ->
    stroke = Util.smooth_stroke stroke, @stroke_smoothing
    @stroke = (Util.rescale bounds, point for point in stroke)
    #@stroke = @drop_close_points @stroke
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
    # Return true if the bounding box is too big to be considered a dot.
    (Util.area bounds[0], bounds[1]) > @area_threshold or
    (Util.perimeter bounds[0], bounds[1]) > @perimeter_threshold

  draw: (canvas) =>
    for segment in @segments
      segment.draw canvas
    for [i, j] in @loops
      canvas.context.strokeStyle = 'purple'
      canvas.draw_point @stroke[i]
      canvas.draw_point @stroke[j - 1]
    for point in @points
      point.draw canvas

  extend: (point1, point2, length) =>
    base_length = Util.distance point1, point2
    if base_length > 0
      return {
        x: point2.x + length/base_length*(point2.x - point1.x)
        y: point2.y + length/base_length*(point2.y - point1.y)
      }
    point2

  find_loops: (stroke, states) =>
    loops = []
    i = 0
    while i < stroke.length
      for j in [3...@loop_count]
        if i + j >= stroke.length
          break
        [u, v, point] = @find_stroke_intersection stroke, i, i + j - 1
        if point and 0 <= u < 1 and 0 <= v < 1
          loops.push [i, i + j + 1]
      i += 1
    loops

  find_stroke_intersection: (stroke, i, j) =>
    [p1, p2, p3, p4] = [stroke[i], stroke[i + 1], stroke[j], stroke[j + 1]]
    if i == 0
      p1 = @extend p2, p1, @loop_tolerance
    if j + 2 == stroke.length
      p4 = @extend p3, p4, @loop_tolerance
    Util.intersection p1, p2, p3, p4

  check_cusp_point: (stroke, i, r, tolerance, color, points) =>
    if i - r < 0 or i + r >= stroke.length
      return
    angle1 = Util.angle stroke[i - r], stroke[i - r + 1]
    angle2 = Util.angle stroke[i + r], stroke[i + r - 1]
    diff = (angle1 - angle2 + 3*Math.PI) % (2*Math.PI) - Math.PI
    if (Math.abs diff) < tolerance
      points.push new Point [stroke[i]], 'cusp'
      points[points.length - 1].color = color
      points[points.length - 1].i = i
      base_confidence = (1 - (Math.abs diff)/tolerance)/r
      adjustment= if color == 'black' then 1 else 0.5
      points[points.length - 1].confidence = adjustment*base_confidence

  find_cusps: (stroke, segments) =>
    points = []
    [r, tolerance] = [2, 0.4*Math.PI]
    for i in [r...stroke.length - r]
      @check_cusp_point stroke, i, r, tolerance, 'black', points
    for segment, i in segments
      if i > 0
        length = 0
        for k in [segment.i...segment.j]
          @check_cusp_point stroke, k, 2*r, 1.5*tolerance, 'brown', points
          if k < stroke.length - 1
            length += Util.distance stroke[k], stroke[k + 1]
          if length > 0.05
            break
      if i < segments.length - 1
        length = 0
        for k in [segment.j - 1..segment.i]
          @check_cusp_point stroke, k, 2*r, 1.5*tolerance, 'brown', points
          if k > 0
            length += Util.distance stroke[k], stroke[k - 1]
          if length > 0.05
            break
    points.sort (point1, point2) -> point1.i - point2.i
    @deduplicate points

  deduplicate: (points) =>
    result = []
    r = 8
    for point in points
      point.color = 'blue'
      if result.length == 0 or point.i > result[result.length - 1].i + r
        result.push point
      else if point.confidence > result[result.length - 1].confidence
        result[result.length - 1] = point
    result

  find_points: (stroke, segments) =>
    if segments.length == 1 and (segments[0].dot or segments[0].closed)
      return @find_singleton_point segments[0]
    return @find_cusps stroke, segments
    points = [
      (new Point [stroke[0]], 'endpoint'),
      (new Point [stroke[stroke.length - 1]], 'endpoint')
    ]
    for segment, i in segments
      if segment.closed
        type = if segment.minor then 'cusp' else 'loop'
        points.push new Point [@stroke[segment.i], @stroke[segment.j - 1]], type
        # TODO(skishore): Detect cusps when they occur within loops...
      else if segment.minor
        if segment.state != 0
          left = i > 0 and segments[i - 1].state + segment.state == 3
          right = i + 1 < segments.length and \
              segments[i + 1].state + segment.state == 3
          [k, l] = [segment.i, segment.j]
          if left and right
            points.push new Point [@stroke[k], @stroke[l - 1]], 'cusp'
          else if left
            points.push new Point [@stroke[k - 1], @stroke[k]], 'cusp'
          else if right
            points.push new Point [@stroke[l - 1], @stroke[l]], 'cusp'
      else if i > 0 and not segments[i - 1].minor and \
          segments[i - 1].state + segments[i].state == 3
        k = segments[i].i
        points.push new Point [@stroke[k - 1], @stroke[k]], 'inflection'
        # TODO(skishore): Add inflection points when a straight segment
        # separates two colored segments of sufficient length to dominate it.
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
    #segments = @merge_straight_segments segments, stroke, states
    #segments = @split_loop_segments segments, stroke, states, loops
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
    memo = [{1: [0, undefined], 2: [0, undefined]}]
    for angle in angles
      new_memo = {}
      for state of @pdfs
        [best_log, best_state] = [-Infinity, undefined]
        for last_state of @pdfs
          [last_log, _] = memo[memo.length - 1][last_state]
          new_log = last_log
          if last_state != state
            if last_state == '0' or state == '0'
              new_log += Math.log @straight_transition_prob
            else
              new_log += Math.log @curved_transition_prob
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
