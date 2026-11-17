class DetailedAnswer {
  final String questionText;
  final String studentAnswer;
  final String correctAnswer;
  final int marksAwarded;
  final int maxMarks;

  DetailedAnswer({
    required this.questionText,
    required this.studentAnswer,
    required this.correctAnswer,
    required this.marksAwarded,
    required this.maxMarks,
  });

  factory DetailedAnswer.fromJson(Map<String, dynamic> json) {
    return DetailedAnswer(
      questionText: json['question_text'] ?? '',
      studentAnswer: json['student_answer'] ?? '',
      correctAnswer: json['correct_answer'] ?? '',
      marksAwarded: json['marks_awarded'] ?? 0,
      maxMarks: json['max_marks'] ?? 1,
    );
  }
}

class StudentResult {
  final String sessionId;
  final String studentId;
  final String studentName; 
  final String studentRoll; 
  final String status;
  final int violationCount;
  final int score;
  final int totalMarks;
  final List<DetailedAnswer> detailedAnswers; 

  StudentResult({
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.studentRoll,
    required this.status,
    required this.violationCount,
    required this.score,
    required this.totalMarks,
    required this.detailedAnswers,
  });

  factory StudentResult.fromJson(Map<String, dynamic> json) {
    return StudentResult(
      sessionId: json['session_id'],
      studentId: json['student_id'],
      studentName: json['student_name'] ?? 'Unknown',
      studentRoll: json['student_roll'] ?? '-',
      status: json['status'],
      violationCount: json['violation_count'],
      score: json['score'],
      totalMarks: json['total_marks'],
      detailedAnswers: (json['detailed_answers'] as List?)
              ?.map((e) => DetailedAnswer.fromJson(e))
              .toList() ?? [],
    );
  }
}