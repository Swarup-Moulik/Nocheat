class SubjectModel {
  final String id;
  final String code;
  final String name;
  final String? assignedTeacherId;
  final String? classId;

  SubjectModel({
    required this.id,
    required this.code,
    required this.name,
    this.assignedTeacherId,
    this.classId,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'] ?? '',
      code: json['code'] ?? 'Unknown',
      name: json['name'] ?? 'Unknown',
      assignedTeacherId: json['assigned_teacher_id'],
      classId: json['class_id'],
    );
  }
}
