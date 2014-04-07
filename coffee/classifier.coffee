class Classifier
  constructor: (@feature, @training_data) ->
    for sample in @training_data
      feature.run sample.data
      sample.strokes = (do feature.serialize).strokes

  classify: (test) =>
    [best_score, best_i] = -Infinity
    for sample, i in @training_data
      score = @score sample, test
      if score > best_score
        [best_score, best_i] = [score, i]
    return [i, @training_data[i]]

  extract_important_segments: (data) =>
    result = []
    for stroke in data.strokes
      segment = @make_single_segment stroke
      if Util.area segment.bounds[0], segment.bounds[1] < @dot_threshold
        result.push segment
      else
        result.push.apply stroke

  score: (sample, test) =>
    sample_segments = @extract_important_segments sample
    test_segments = @extract_important_segments test
