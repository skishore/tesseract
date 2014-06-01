class @Classifier
  constructor: (@feature, @training_data) ->
    setTimeout @initialize, 0
    window.classifier = @

  initialize: =>
    for sample in @training_data
      @feature.run sample.data
      sample.strokes = (do @feature.serialize).strokes
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

  extract_points: (data, major_only) =>
    result = []
    for stroke in data.strokes
      for point in stroke.points
        result.push point
    result

  score: (sample, test) =>
    missing_sample_point_penalty = -1.0

    sample_points = @extract_points sample
    test_points = @extract_points test
    if sample_points.length == 0
      return -Infinity

    matrix = []
    best_match = ([-1, -Infinity] for test_point in test_points)
    # Score all major sample segments. Note that a sample segment can match
    # with a minor test segment, because the test data is noisy.
    for sample_point, i in sample_points
      matrix.push []
      for test_point, j in test_points
        score = @score_points sample_point, test_point
        matrix[i].push score
        if score > best_match[j][1]
          best_match[j] = [i, score]
      for j in [0...sample_points.length]
        matrix[i].push missing_sample_point_penalty
    for i in [0...test_points.length]
      matrix.push []
      for j in [0...test_points.length]
        matrix[sample_points.length + i].push best_match[j][1]
      for j in [0...sample_points.length]
        matrix[sample_points.length + i].push 0
    # Run the Hungarian algorithm to find the optimal matching in our matrix.
    # We divide this score by the number of sample points, because we don't
    # want to penalize scores for complex characters.
    hungarian = new Hungarian matrix
    (hungarian.get_final_score matrix)/sample_points.length

  score_points: (a, b) =>
    distance_penalty = -1.0
    type_mismatch_penalty = -0.5

    score = distance_penalty*Util.distance a, b
    if a.type != b.type
      score += type_mismatch_penalty
    score
