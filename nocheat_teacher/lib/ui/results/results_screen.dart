import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/student_result.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  List<dynamic> _exams = [];
  bool _isLoadingExams = true;

  dynamic _selectedExam;
  List<StudentResult> _results = [];
  bool _isLoadingResults = false;

  @override
  void initState() {
    super.initState();
    _fetchExams();
  }

  Future<void> _fetchExams() async {
    setState(() => _isLoadingExams = true);
    final exams = await ApiClient.fetchTeacherExams();
    setState(() {
      _exams = exams;
      _isLoadingExams = false;
    });
  }

  Future<void> _fetchResults(dynamic exam) async {
    setState(() {
      _selectedExam = exam;
      _isLoadingResults = true;
    });
    final results = await ApiClient.fetchExamResults(exam['id']);
    setState(() {
      _results = results;
      _isLoadingResults = false;
    });
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _confirmDeleteExam() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Are you sure?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Do you want to permanently delete this exam and all associated student submissions? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteExam();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              'Yes, Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExam() async {
    if (_selectedExam == null) return;
    setState(() => _isLoadingResults = true);
    final success = await ApiClient.deleteExam(_selectedExam['id']);

    if (success) {
      setState(() => _selectedExam = null);
      await _fetchExams();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exam deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
    } else {
      setState(() => _isLoadingResults = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Failed to delete the exam.'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  void _showAnswersDialog(StudentResult result) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '${result.studentName} - Answers',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: ListView.builder(
              itemCount: result.detailedAnswers.length,
              itemBuilder: (context, index) {
                final ans = result.detailedAnswers[index];
                final isCorrect = ans.marksAwarded == ans.maxMarks;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Q: ${ans.questionText}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              'Answer: ',
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              ans.studentAnswer,
                              style: TextStyle(
                                color: isCorrect
                                    ? Colors.green
                                    : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (!isCorrect) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text(
                                'Correct: ',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                ans.correctAnswer,
                                style: const TextStyle(color: Colors.green),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Marks: ${ans.marksAwarded} / ${ans.maxMarks}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.blueGrey),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_selectedExam != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _selectedExam = null),
                ),
              Text(
                _selectedExam == null
                    ? 'Published Exams'
                    : 'Submissions: ${_selectedExam['title']}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_selectedExam != null) ...[
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _confirmDeleteExam,
                  icon: const Icon(Icons.delete, color: Colors.white, size: 18),
                  label: const Text('Delete Exam'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _selectedExam == null
                ? _buildExamsList()
                : _buildResultsTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildExamsList() {
    if (_isLoadingExams)
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueGrey),
      );
    if (_exams.isEmpty)
      return const Center(
        child: Text(
          "You haven't created any exams yet.",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );

    final now = DateTime.now();
    final activeExams = [];
    final expiredExams = [];

    for (var exam in _exams) {
      DateTime? end;
      if (exam['end_time'] != null)
        end = DateTime.tryParse(exam['end_time'])?.toLocal();

      if (end != null && now.isAfter(end)) {
        expiredExams.add(exam);
      } else {
        activeExams.add(exam);
      }
    }

    return ListView(
      children: [
        if (activeExams.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Active & Upcoming Exams',
              style: TextStyle(
                color: Colors.blueGrey,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ...activeExams.map((exam) => _buildExamCard(exam, isActive: true)),
          const SizedBox(height: 24),
        ],

        if (expiredExams.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Expired Exams',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ...expiredExams.map((exam) => _buildExamCard(exam, isActive: false)),
        ],
      ],
    );
  }

  Widget _buildExamCard(dynamic exam, {required bool isActive}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime? start;
    DateTime? end;
    if (exam['start_time'] != null)
      start = DateTime.tryParse(exam['start_time'])?.toLocal();
    if (exam['end_time'] != null)
      end = DateTime.tryParse(exam['end_time'])?.toLocal();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          isActive ? Icons.assignment : Icons.history,
          color: isActive ? Colors.blueGrey : Colors.grey,
        ),
        title: Text(
          exam['title'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? null : Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Duration: ${exam['duration_minutes'] ?? 60} mins  |  Total Marks: ${exam['total_marks']}',
            ),
            if (start != null && end != null)
              Text(
                'Window: ${_formatDate(start)} - ${_formatDate(end)}',
                style: TextStyle(
                  color: isActive
                      ? (isDark ? Colors.blueGrey[300] : Colors.blueGrey[700])
                      : Colors.grey,
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isActive ? Colors.grey : Colors.grey[300],
          size: 16,
        ),
        onTap: () => _fetchResults(exam),
      ),
    );
  }

  Widget _buildResultsTable() {
    if (_isLoadingResults)
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueGrey),
      );
    if (_results.isEmpty)
      return const Center(
        child: Text(
          "No submissions found for this exam.",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );

    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: DataTable(
          headingTextStyle: const TextStyle(
            color: Colors.blueGrey,
            fontWeight: FontWeight.bold,
          ),
          columns: const [
            DataColumn(label: Text('Student Name')),
            DataColumn(label: Text('Roll No')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Final Score')),
            DataColumn(label: Text('Penalties')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _results.map((r) {
            final isCheater = r.violationCount > 0;
            return DataRow(
              cells: [
                DataCell(Text(r.studentName)),
                DataCell(Text(r.studentRoll)),
                DataCell(
                  Text(
                    r.status.toUpperCase(),
                    style: TextStyle(
                      color: r.status == 'submitted'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${r.score} / ${r.totalMarks}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      if (isCheater)
                        const Icon(
                          Icons.warning,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                      if (isCheater) const SizedBox(width: 8),
                      Text(
                        r.violationCount.toString(),
                        style: TextStyle(
                          color: isCheater ? Colors.redAccent : null,
                          fontWeight: isCheater
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(
                      Icons.visibility,
                      color: Colors.blueAccent,
                    ),
                    tooltip: 'View Answers',
                    onPressed: () => _showAnswersDialog(r),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
