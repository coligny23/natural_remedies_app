class E5SearchResult {
  final String id;
  final String title;
  final String? titleSw;
  final double score;
  final double semanticScore;
  final double lexicalScore;

  const E5SearchResult({
    required this.id,
    required this.title,
    this.titleSw,
    required this.score,
    required this.semanticScore,
    required this.lexicalScore,
  });
}