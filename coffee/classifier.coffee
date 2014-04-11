class @Classifier
  constructor: (@feature, @training_data) ->
    setTimeout @initialize, 0
    window.classifier = @

  initialize: =>
    for sample in @training_data
      @feature.run sample.data
      sample.strokes = (do feature.serialize).strokes
    @ready = true

  classify: (test) =>
    if not @ready
      return [0, @training_data[0]]
    [best_i, best_score] = [-1, -Infinity]
    for sample, i in @training_data
      score = @score sample, test
      if score > best_score
        [best_i, best_score] = [i, score]
    [best_i, @training_data[best_i]]

  extract_segments: (data, major_only) =>
    result = []
    for stroke in data.strokes
      for segment in stroke
        if not (major_only and segment.minor)
          result.push segment
    result

  score: (sample, test) =>
    sample_weight = 1.0
    test_weight = 1.0

    sample_segments = @extract_segments sample, true
    test_segments = @extract_segments test
    # Score all major sample segments. Note that a sample segment can match
    # with a minor test segment, because the test data is noisy.
    sample_matches = []
    for sample_segment in sample_segments
      [best_i, best_score] = [-1, -Infinity]
      for test_segment, i in test_segments
        score = @score_segments sample_segment, test_segment
        if score > best_score
          [best_i, best_score] = [i, score]
      sample_matches.push [best_i, best_score]
    sample_score = Util.sum (score for [i, score] in sample_matches)
    # Score all major test segments. Note that a test segment cannot match
    # with a minor sample segment because the sample data is good.
    test_matches = []
    for test_segment in test_segments
      if test_segment.minor
        continue
      [best_i, best_score] = [-1, -Infinity]
      for sample_segment, i in sample_segments
        score = @score_segments test_segment, sample_segment
        if score > best_score
          [best_i, best_score] = [i, score]
      test_matches.push [best_i, best_score]
    test_score = Util.sum (score for [i, score] in test_matches)
    # Return the final weighted score.
    #
    # We divide this score by the number of sample segments, because we don't
    # want to penalize scores for complex characters.
    (sample_weight*sample_score + test_weight*test_score)/sample_segments.length

  score_segments: (a, b) =>
    minor_state_penalty = -1.0
    major_state_penalty = -3.0
    bounds_x_penalty = -2.0
    bounds_y_penalty = -2.0
    endpoint_x_penalty = -0.4
    endpoint_y_penalty = -0.4
    length_penalty = -1.0
    closed_penalty = -10.0
    dot_penalty = -20.0

    score = 0
    # Apply the state penalties, multiplied by length.
    if a.state + b.state == 3
      score += a.length*major_state_penalty
    else if a.state != b.state
      score += a.length*minor_state_penalty
    # Apply the bounds penalties.
    score += bounds_x_penalty*@sq_diff a.bounds[0].x, b.bounds[0].x
    score += bounds_y_penalty*@sq_diff a.bounds[0].y, b.bounds[0].y
    score += bounds_x_penalty*@sq_diff a.bounds[1].x, b.bounds[1].x
    score += bounds_y_penalty*@sq_diff a.bounds[1].y, b.bounds[1].y
    # Apply the endpoint penalties.
    score += endpoint_x_penalty*@sq_diff a.start.x, b.start.x
    score += endpoint_y_penalty*@sq_diff a.start.y, b.start.y
    score += endpoint_x_penalty*@sq_diff a.end.x, b.end.x
    score += endpoint_y_penalty*@sq_diff a.end.y, b.end.y
    # Apply the length penalties.
    score += length_penalty*@sq_diff a.length, b.length
    # Apply the closed and dot penalties.
    if a.closed != b.closed
      score += closed_penalty
    if a.dot != b.dot
      score += dot_penalty
    score

  sq_diff: (x, y) ->
    (x - y)*(x - y)
