class TranscriptSegment {
  final double start;
  final double end;
  final String text;

  TranscriptSegment({required this.start, required this.end, required this.text});

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      text: json['text'] as String,
    );
  }
}

class Transcript {
  final String text;
  final String language;
  final double duration;
  final List<TranscriptSegment> segments;

  Transcript({
    required this.text,
    required this.language,
    required this.duration,
    required this.segments,
  });

  factory Transcript.fromJson(Map<String, dynamic> json) {
    return Transcript(
      text: json['text'] as String? ?? '',
      language: json['language'] as String? ?? '',
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      segments: (json['segments'] as List<dynamic>? ?? [])
          .map((e) => TranscriptSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
