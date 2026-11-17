import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user.dart';
import '../models/subject.dart';
import '../models/class_group.dart';
import '../models/assignment.dart';

class ApiClient {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  // This will be set when the admin logs in
  static String currentInstituteId = '';

  static void logout() {
    currentInstituteId = '';
  }

  static Future<Map<String, dynamic>?> loginAdmin(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Login Error: $e");
    }
    return null;
  }

  // --- USERS ---

  static Future<bool> createUser(
    String name,
    String email,
    String role, {
    String? studentRoll,
    String? classId,
  }) async {
    try {
      final payload = {
        'institute_id': currentInstituteId,
        'name': name,
        'email': email,
        'role': role,
      };

      if (studentRoll != null && studentRoll.isNotEmpty) {
        payload['student_roll'] = studentRoll;
      }
      if (classId != null && classId.isNotEmpty) {
        payload['class_id'] = classId;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/admin/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<List<UserModel>> fetchUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/users?institute_id=$currentInstituteId'),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => UserModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> deleteUser(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/users/$userId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateUserClass(String userId, String classId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/users/$userId/class'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'class_id': classId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error updating user class: $e");
      return false;
    }
  }

  // --- SUBJECTS ---

  static Future<bool> createSubject(
    String code,
    String name,
    String classId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/subjects'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'institute_id': currentInstituteId,
          'code': code,
          'name': name,
          'class_id': classId,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<List<SubjectModel>> fetchSubjects() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/subjects?institute_id=$currentInstituteId'),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => SubjectModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> deleteSubject(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/subjects/$id'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- CLASSES ---

  static Future<bool> createClass(String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/classes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'institute_id': currentInstituteId, 'name': name}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<List<ClassModel>> fetchClasses() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/classes?institute_id=$currentInstituteId'),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => ClassModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> deleteClass(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/classes/$id'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- ASSIGNMENTS ---
  static Future<bool> assignTeacher(
    String classId,
    String subjectId,
    String teacherId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/assignments'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'institute_id': currentInstituteId,
          'class_id': classId,
          'subject_id': subjectId,
          'teacher_id': teacherId,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<List<AssignmentModel>> fetchAssignments() async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/admin/assignments?institute_id=$currentInstituteId',
        ),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => AssignmentModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> deleteAssignment(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/assignments/$id'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
