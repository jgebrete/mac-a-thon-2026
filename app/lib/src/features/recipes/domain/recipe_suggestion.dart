class RecipeSuggestion {
  RecipeSuggestion({
    required this.title,
    required this.ingredients,
    required this.steps,
    required this.rationale,
    required this.usesExpiring,
  });

  final String title;
  final List<String> ingredients;
  final List<String> steps;
  final String rationale;
  final List<String> usesExpiring;

  factory RecipeSuggestion.fromJson(Map<String, dynamic> json) {
    return RecipeSuggestion(
      title: (json['title'] as String?)?.trim() ?? 'Untitled Recipe',
      ingredients: (json['ingredients'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(growable: false),
      steps: (json['steps'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(growable: false),
      rationale: (json['rationale'] as String?)?.trim() ?? '',
      usesExpiring: (json['usesExpiring'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(growable: false),
    );
  }
}
