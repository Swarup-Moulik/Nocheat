class Question {
  final String id;
  final String text;
  final List<String> options;

  Question({required this.id, required this.text, required this.options});

  // This factory will parse the future JSON payload from your backend
  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      text: json['text'],
      options: List<String>.from(json['options']),
    );
  }
}
