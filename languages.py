import string


class Language(object):
  # To define a language, override these class variables:
  #   code: The three letter language code for the language.
  #   alphabet: Unicode string containing the characters in the language.
  code = None
  alphabet = None


class English(Language):
  code = 'eng'
  alphabet = unicode(string.letters[26:])


class Kannada(Language):
  code = 'kan'

  vowel_indices = set(xrange(3205, 3221))
  vowel_indices -= set([3213, 3217])
  vowel_indices |= set([3296, 3297])

  consonant_indices = set(xrange(3221, 3258))
  consonant_indices -= set([3241, 3252])
  consonant_indices |= set([3294])

  vowels = u''.join(map(unichr, sorted(vowel_indices)))
  consonants = u''.join(map(unichr, sorted(consonant_indices)))

  alphabet = vowels + consonants
