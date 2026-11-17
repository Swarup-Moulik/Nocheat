class AssignmentModel {
  final String id;
  final String classId;
  final String subjectId;
  final String teacherId;

  AssignmentModel({
    required this.id,
    required this.classId,
    required this.subjectId,
    required this.teacherId,
  });

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    return AssignmentModel(
      id: json['id'],
      classId: json['class_id'],
      subjectId: json['subject_id'],
      teacherId: json['teacher_id'],
    );
  }
}
