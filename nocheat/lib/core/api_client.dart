import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiClient {
  static const String baseUrl = 'http://127.0.0.1:8000/api'; 

  // Global Session State
  static String currentStudentId = '';
  static String currentStudentName = '';
  static String currentStudentRoll = '';
  static String currentClassName = '';
  static String currentInstituteId = '';

  static Future<bool> loginStudent(String email, String roll) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/student/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'student_roll': roll}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        currentStudentId = data['id'];
        currentStudentName = data['name'];
        currentStudentRoll = data['student_roll'];
        currentClassName = data['class_name'];
        currentInstituteId = data['institute_id'];
        return true;
      }
    } catch (e) {
      debugPrint("Login Error: $e");
    }
    return false;
  }

  static void logout() {
    currentStudentId = '';
    currentStudentName = '';
    currentStudentRoll = '';
    currentClassName = '';
    currentInstituteId = '';
  }

  static Future<List<dynamic>> fetchSubjects() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/student/$currentStudentId/subjects'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Error fetching subjects: $e");
    }
    return [];
  }

  static Future<List<dynamic>> fetchExams(String subjectId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/student/$currentStudentId/subjects/$subjectId/exams'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Error fetching exams: $e");
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchExamDetails(String examId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/student/exams/$examId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Error fetching exam details: $e");
    }
    return null;
  }

  static Future<String?> joinExam(String examId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/student/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'exam_id': examId,
          'student_id': currentStudentId,
          'institute_id': currentInstituteId,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['session_id'];
      }
    } catch (e) {
      debugPrint("Error joining exam: $e");
    }
    return null;
  }
}