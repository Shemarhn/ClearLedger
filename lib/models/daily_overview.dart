class DailyOverview {
  final String generatedFor;
  final String summary;
  final List<String> insights;
  final List<String> suggestions;
  final Map<String, dynamic> totals;

  const DailyOverview({
    required this.generatedFor,
    required this.summary,
    required this.insights,
    required this.suggestions,
    required this.totals,
  });

  factory DailyOverview.fromJson(Map<String, dynamic> json) {
    return DailyOverview(
      generatedFor: json['generated_for'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      insights: (json['insights'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      suggestions: (json['suggestions'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      totals: Map<String, dynamic>.from(json['totals'] as Map? ?? const {}),
    );
  }
}
