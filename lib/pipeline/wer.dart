class ErrorRate {
  const ErrorRate({
    required this.substitutions,
    required this.insertions,
    required this.deletions,
    required this.referenceLength,
  });

  final int substitutions;
  final int insertions;
  final int deletions;
  final int referenceLength;

  int get errors => substitutions + insertions + deletions;

  /// (S + D + I) / N. An empty reference gives 0 if the hypothesis is also
  /// empty, otherwise 1.
  double get rate {
    if (referenceLength == 0) return errors == 0 ? 0 : 1;
    return errors / referenceLength;
  }

  @override
  String toString() =>
      'ErrorRate(${(rate * 100).toStringAsFixed(1)}%, S=$substitutions, '
      'I=$insertions, D=$deletions, N=$referenceLength)';
}

class WerCalculator {
  const WerCalculator();

  static final _apostrophes = RegExp(r"['’‘`]");
  static final _punctuation = RegExp(r'[^\p{L}\p{M}\p{N}\s]', unicode: true);
  static final _spaces = RegExp(r'\s+');

  /// Lowercases, drops apostrophes ("what's" → "whats"), turns other
  /// punctuation into spaces and collapses whitespace. Combining marks are
  /// kept so Devanagari matras survive.
  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll(_apostrophes, '')
      .replaceAll(_punctuation, ' ')
      .replaceAll(_spaces, ' ')
      .trim();

  ErrorRate wer(String reference, String hypothesis) {
    List<String> words(String s) {
      final n = normalize(s);
      return n.isEmpty ? const [] : n.split(' ');
    }

    return _align(words(reference), words(hypothesis));
  }

  /// Character error rate over Unicode code points, spaces included.
  ErrorRate cer(String reference, String hypothesis) => _align(
    normalize(reference).runes.toList(),
    normalize(hypothesis).runes.toList(),
  );

  static ErrorRate _align<T>(List<T> ref, List<T> hyp) {
    final n = ref.length, m = hyp.length;
    final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = 0; i <= n; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= m; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final cost = ref[i - 1] == hyp[j - 1] ? 0 : 1;
        final sub = d[i - 1][j - 1] + cost;
        final del = d[i - 1][j] + 1;
        final ins = d[i][j - 1] + 1;
        d[i][j] = sub < del ? (sub < ins ? sub : ins) : (del < ins ? del : ins);
      }
    }

    var s = 0, ins = 0, del = 0;
    var i = n, j = m;
    while (i > 0 || j > 0) {
      if (i > 0 &&
          j > 0 &&
          d[i][j] == d[i - 1][j - 1] + (ref[i - 1] == hyp[j - 1] ? 0 : 1)) {
        if (ref[i - 1] != hyp[j - 1]) s++;
        i--;
        j--;
      } else if (i > 0 && d[i][j] == d[i - 1][j] + 1) {
        del++;
        i--;
      } else {
        ins++;
        j--;
      }
    }
    return ErrorRate(
      substitutions: s,
      insertions: ins,
      deletions: del,
      referenceLength: n,
    );
  }
}
