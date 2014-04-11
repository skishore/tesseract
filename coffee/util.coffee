class @Util
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

  @area: (point1, point2) ->
    Math.abs (point2.x - point1.x)*(point2.y - point1.y)

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

  @perimeter: (point1, point2) ->
    2*(Math.abs(point2.x - point1.x) + Math.abs(point2.y - point1.y))

  @rescale: (bounds, point) ->
    # Takes a list of points within the given bounds, and rescales them so that
    # the points are bounded within the unit square.
    [min, max] = bounds
    x: (max.x - min.x) and (point.x - min.x)/(max.x - min.x)
    y: (max.y - min.y) and (point.y - min.y)/(max.y - min.y)

  @sign: (x) ->
    if x then (if x < 0 then -1 else 1) else 0

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
