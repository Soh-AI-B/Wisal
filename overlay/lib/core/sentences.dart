import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// صلة الرحم motivational sentences, bundled identically as an Android raw resource
/// so the home screen and the daily notification always agree on "today's" pick.
final sentencesProvider = FutureProvider<List<String>>((ref) async {
  final raw = await rootBundle.loadString('assets/sentences.txt');
  return raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
});

class QuoteOfDay {
  static int _epochDay() => DateTime.now().millisecondsSinceEpoch ~/ 86400000;

  static String forToday(List<String> sentences) {
    if (sentences.isEmpty) return '';
    return sentences[_epochDay() % sentences.length];
  }

  static String random(List<String> sentences) {
    if (sentences.isEmpty) return '';
    return sentences[Random().nextInt(sentences.length)];
  }
}
