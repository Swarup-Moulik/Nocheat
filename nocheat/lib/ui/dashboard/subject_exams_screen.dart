import 'package:flutter/material.dart';

import 'dart:io' show Platform;

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/native_bridge.dart';
import '../exam/exam_screen.dart';

class SubjectExamsScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const SubjectExamsScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<SubjectExamsScreen> createState() => _SubjectExamsScreenState();
}

class _SubjectExamsScreenState extends State<SubjectExamsScreen> {
  List<dynamic> _exams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    final exams = await ApiClient.fetchExams(widget.subjectId);
    setState(() {
      _exams = exams;
      _isLoading = false;
    });
  }

  Future<void> _startSecureExam(String examId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_exam_id', examId);
    await prefs.setString('active_student_id', ApiClient.currentStudentId);
    await prefs.setString('active_institute_id', ApiClient.currentInstituteId);

    bool success = await NativeBridge().triggerLockdown();
    if (!mounted) return;

    if (success) {
      if (Platform.isAndroid) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => ExamScreen(examId: examId)),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to initialize secure environment.'),
        ),
      );
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subjectName),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _exams.isEmpty
          ? const Center(
              child: Text(
                "No exams assigned yet.",
                style: TextStyle(fontSize: 16),
              ),
            )
          : _buildExamList(),
    );
  }

  Widget _buildExamList() {
    final now = DateTime.now();
    final activeExams = [];
    final expiredExams = [];

    // Split exams based on expiration
    for (var exam in _exams) {
      DateTime? end;
      if (exam['end_time'] != null) {
        end = DateTime.tryParse(exam['end_time'])?.toLocal();
      }

      if (end != null && now.isAfter(end)) {
        expiredExams.add(exam);
      } else {
        activeExams.add(exam);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (activeExams.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 12.0),
            child: Text(
              'Active & Upcoming Exams',
              style: TextStyle(
                color: Colors.blueGrey,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          ...activeExams.map((exam) => _buildExamCard(exam, now)),
          const SizedBox(height: 32),
        ],
        if (expiredExams.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 12.0),
            child: Text(
              'Expired Exams',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          ...expiredExams.map((exam) => _buildExamCard(exam, now)),
        ],
      ],
    );
  }

  Widget _buildExamCard(dynamic exam, DateTime now) {
    final bool isCompleted = exam['status'] == 'submitted';

    // --- Time Window Logic ---
    DateTime? start;
    DateTime? end;
    if (exam['start_time'] != null) {
      start = DateTime.tryParse(exam['start_time'])?.toLocal();
    }
    if (exam['end_time'] != null) {
      end = DateTime.tryParse(exam['end_time'])?.toLocal();
    }

    bool isAvailable = false;
    bool hasEnded = false;
    bool isTooEarly = false;

    if (start != null && end != null) {
      if (now.isBefore(start)) {
        isTooEarly = true;
      } else if (now.isAfter(end)) {
        hasEnded = true;
      } else {
        isAvailable = true;
      }
    } else {
      isAvailable = true; // Fallback if dates were somehow omitted
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam['title'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Display details
                  Text(
                    'Duration: ${exam['duration_minutes']} mins  |  Total Marks: ${exam['total_marks']}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  if (start != null && end != null)
                    Text(
                      'Window: ${_formatDate(start)} to ${_formatDate(end)}',
                      style: TextStyle(
                        color: hasEnded
                            ? Colors.redAccent
                            : Colors.blueGrey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 8),

                  if (isCompleted)
                    Text(
                      'Score: ${exam['score']} / ${exam['total_marks']}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),

            // --- Dynamic Button Logic ---
            if (isCompleted)
              const Chip(
                label: Text('Completed', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.green,
              )
            else if (hasEnded)
              const Chip(
                label: Text('Missed', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.redAccent,
              )
            else if (isTooEarly)
              const Chip(
                label: Text(
                  'Waiting for start time...',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.orange,
              )
            else if (isAvailable)
              ElevatedButton.icon(
                onPressed: () => _startSecureExam(exam['id']),
                icon: const Icon(Icons.lock),
                label: const Text('Start Exam'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[900],
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
