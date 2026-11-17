class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? studentRoll;
  String? classId;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.studentRoll,
    this.classId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      email: json['email'] ?? 'Unknown',
      role: json['role'] ?? 'student',
      studentRoll: json['student_roll'],
      classId: json['class_id'],
    );
  }
}
