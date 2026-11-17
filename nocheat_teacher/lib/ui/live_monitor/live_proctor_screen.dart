import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/api_client.dart';
import '../../models/student_result.dart';

class LiveProctorScreen extends StatefulWidget {
  const LiveProctorScreen({super.key});

  @override
  State<LiveProctorScreen> createState() => _LiveProctorScreenState();
}

class _LiveProctorScreenState extends State<LiveProctorScreen> {
  List<dynamic> _exams = [];
  bool _isLoadingExams = true;

  dynamic _selectedExam;
  List<StudentResult> _cheaters = [];
  bool _isLoadingCheaters = false;

  WebSocketChannel? _channel;
  final List _liveAlerts = [];

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

  Future<void> _selectExam(dynamic exam) async {
    setState(() {
      _selectedExam = exam;
      _isLoadingCheaters = true;
      _liveAlerts.clear();
    });

    await _refreshCheatersList();
    _connectWebSocket(exam['id']);
  }

  Future<void> _refreshCheatersList() async {
    if (_selectedExam == null) return;
    final results = await ApiClient.fetchExamResults(_selectedExam['id']);
    if (mounted) {
      setState(() {
        _cheaters = results.where((r) => r.violationCount > 0).toList();
        _isLoadingCheaters = false;
      });
    }
  }

  void _connectWebSocket(String examId) {
    _channel?.sink.close();
    final wsBase = ApiClient.baseUrl
        .replaceFirst('http', 'ws')
        .replaceAll('/api', '');
    final String wsUrl = "$wsBase/ws/teacher/$examId";

    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _channel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        if (mounted) {
          setState(() => _liveAlerts.insert(0, data));
          _refreshCheatersList();
        }
      },
      onError: (error) => debugPrint("WebSocket Error: $error"),
      onDone: () => debugPrint("WebSocket Disconnected"),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
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
                  onPressed: () {
                    _channel?.sink.close();
                    setState(() => _selectedExam = null);
                  },
                ),
              Text(
                _selectedExam == null
                    ? 'Published Exams'
                    : 'Live Monitor: ${_selectedExam['title']}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _selectedExam == null
                ? _buildExamsList()
                : _buildProctorView(),
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
      return const Center(child: Text("You haven't published any exams yet."));

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
          isActive ? Icons.monitor_heart : Icons.history,
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
        onTap: () => _selectExam(exam),
      ),
    );
  }

  Widget _buildProctorView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoadingCheaters)
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueGrey),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Identified Violations",
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_cheaters.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 24.0),
            child: Text(
              "No penalties have been recorded for this exam yet.",
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: DataTable(
              headingTextStyle: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
              columns: const [
                DataColumn(label: Text('Student Name')),
                DataColumn(label: Text('Roll No')),
                DataColumn(label: Text('Penalty Count')),
              ],
              rows: _cheaters.map((c) {
                return DataRow(
                  cells: [
                    DataCell(Text(c.studentName)),
                    DataCell(Text(c.studentRoll)),
                    DataCell(
                      Row(
                        children: [
                          const Icon(
                            Icons.warning,
                            color: Colors.redAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            c.violationCount.toString(),
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        const Divider(height: 32),
        const Text(
          "Live Event Feed",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _liveAlerts.isEmpty
              ? const Center(
                  child: Text(
                    'Monitoring active... Listening for live events.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: _liveAlerts.length,
                  itemBuilder: (context, index) {
                    final alert = _liveAlerts[index];
                    final timestamp = DateTime.parse(alert['timestamp'])
                        .toLocal();
                    final timeString =
                        "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}";
                    return Card(
                      color: isDark
                          ? const Color(0xFF2A1010)
                          : Colors.red[50], // Soft red warning color for alerts
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(
                          color: Colors.redAccent,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.redAccent,
                          size: 32,
                        ),
                        title: Text(
                          'Violation Detected: Student ID ${alert['student_id']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          'Total Offenses: ${alert['violation_count']}\nTime: $timeString',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
