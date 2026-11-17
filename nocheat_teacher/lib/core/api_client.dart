import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/student_result.dart';

class ApiClient {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  // Global Session State
  static String currentInstituteId = '';
  static String currentTeacherId = '';
  static void logout() {
    currentInstituteId = '';
    currentTeacherId = '';
  }

  static Future<Map<String, dynamic>?> loginTeacher(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print("Error logging in: $e");
    }
    return null;
  }

  static Future<List<dynamic>> fetchTeacherExams() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/$currentTeacherId/exams'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print("Error fetching teacher exams: $e");
    }
    return [];
  }

  static Future<List<dynamic>> fetchTeacherAssignments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/$currentTeacherId/assignments'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print("Error fetching assignments: $e");
    }
    return [];
  }

  static Future<List<StudentResult>> fetchExamResults(String examId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/exams/$examId/results'),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => StudentResult.fromJson(e)).toList();
      }
    } catch (e) {
      print("Error fetching results: $e");
    }
    return [];
  }

  static Future<String?> createExam(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher/exams'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body)['id'];
      }
    } catch (e) {
      print("Error creating exam: $e");
    }
    return null;
  }

  static Future<bool> deleteExam(String examId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/teacher/exams/$examId'));
      return response.statusCode == 200;
    } catch (e) {
      print("Error deleting exam: $e");
      return false;
    }
  }
}
