import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'dart:io' show Platform, exit;

import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/native_bridge.dart';
import '../../../core/sync_manager.dart';
import '../../../core/api_client.dart';
import '../dashboard/student_dashboard.dart';
import '../../models/question.dart';

class ExamScreen extends StatefulWidget {
  final String examId;
  const ExamScreen({super.key, required this.examId});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  bool _isExamActive = true;
  bool _isLoading = true;

  // Main Exam Timer
  int _examSecondsRemaining = 0;
  Timer? _examTimer;

  // Penalty properties
  bool _isFrozen = false;
  int _freezeSecondsRemaining = 0;
  Timer? _freezeTimer;
  int _penaltyDuration = 60; // Default, overwritten by backend

  // Exam State Engine
  int _currentIndex = 0;
  final Map<String, String> _answers = {};

  // --- NEW: Track questions marked for review ---
  final Set<String> _markedForReview = {};

  List<Question> _questions = [];

  // Network State
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  late String _sessionId;
  String get _studentId => ApiClient.currentStudentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeExam();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (!results.contains(ConnectivityResult.none)) {
        SyncManager.syncOfflineData(ApiClient.baseUrl);
      }
    });
  }

  Future<void> _initializeExam() async {
    final sessionId = await ApiClient.joinExam(widget.examId);
    if (sessionId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Could not join exam.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
      return;
    }
    _sessionId = sessionId;

    final examData = await ApiClient.fetchExamDetails(widget.examId);

    if (examData != null && examData['questions'] != null) {
      final int durationMins =
          (examData['duration_minutes'] as num?)?.toInt() ?? 60;
      final int penaltySecs =
          (examData['penalty_seconds'] as num?)?.toInt() ?? 60;

      setState(() {
        _questions = (examData['questions'] as List)
            .map((q) => Question.fromJson(q))
            .toList();
        _examSecondsRemaining = durationMins * 60;
        _penaltyDuration = penaltySecs;
        _isLoading = false;
      });

      _startMainExamTimer();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading questions.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _startMainExamTimer() {
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_examSecondsRemaining > 0) {
        setState(() => _examSecondsRemaining--);
      } else {
        timer.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Time is up! Auto-submitting exam...',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        _submitExam();
      }
    });
  }

  String get _formattedTime {
    final h = _examSecondsRemaining ~/ 3600;
    final m = (_examSecondsRemaining % 3600) ~/ 60;
    final s = _examSecondsRemaining % 60;
    if (h > 0)
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _formattedPenaltyTime {
    final m = _freezeSecondsRemaining ~/ 60;
    final s = _freezeSecondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _freezeTimer?.cancel();
    _examTimer?.cancel();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_isExamActive) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_isFrozen) return;
      _freezeTimer?.cancel();
      setState(() {
        _isFrozen = true;
        _freezeSecondsRemaining = _penaltyDuration;
      });
      _reportViolationToBackend();
    } else if (state == AppLifecycleState.resumed) {
      if (_isFrozen) _startPenaltyCountdown();
    }
  }

  Future<void> _reportViolationToBackend() async {
    final payload = {
      'session_id': _sessionId,
      'student_id': _studentId,
      'event_type': 'focus_lost',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/student/violation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200 && response.statusCode != 201)
        throw Exception("Server rejected payload");
    } catch (e) {
      await SyncManager.queueRequest('/student/violation', payload);
    }
  }

  void _startPenaltyCountdown() {
    _freezeTimer?.cancel();
    _freezeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_freezeSecondsRemaining > 1) {
        setState(() => _freezeSecondsRemaining--);
      } else {
        timer.cancel();
        setState(() {
          _isFrozen = false;
          _freezeSecondsRemaining = 0;
        });
      }
    });
  }

  Future<void> _submitExam() async {
    _isExamActive = false;
    _freezeTimer?.cancel();
    _examTimer?.cancel();

    final payload = {
      'session_id': _sessionId,
      'student_id': _studentId,
      'answers': _answers,
      'client_submission_time': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/student/submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200 && response.statusCode != 201)
        throw Exception("Server rejected submission");
    } catch (e) {
      await SyncManager.queueRequest('/student/submit', payload);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Offline mode: Exam saved locally. Will sync when online.",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
    }

    if (Platform.isAndroid) {
      await NativeBridge().releaseLockdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Exam submitted successfully.",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const StudentDashboard()),
        );
      }
    } else if (Platform.isWindows) {
      exit(0);
    }
  }

  // --- Horizontal Scroll Bar Navigator ---
  Widget _buildQuestionNavigator() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _questions.length,
        itemBuilder: (context, index) {
          final qId = _questions[index].id;
          final isCurrent = index == _currentIndex;
          final isAnswered = _answers.containsKey(qId);
          final isMarked = _markedForReview.contains(qId);

          Color bgColor = Colors.grey[300]!;
          Color textColor = Colors.black87;
          Border? border;

          if (isCurrent) {
            border = Border.all(color: Colors.blue, width: 2.5);
          }

          if (isMarked) {
            bgColor = Colors.orangeAccent;
            textColor = Colors.white;
          } else if (isAnswered) {
            bgColor = Colors.green;
            textColor = Colors.white;
          }

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _currentIndex = index),
              child: Container(
                width: 50,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: border,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExamContent() {
    final currentQuestion = _questions[_currentIndex];
    final isMarked = _markedForReview.contains(currentQuestion.id);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Render the Question Navigator Bar ---
          _buildQuestionNavigator(),
          const SizedBox(height: 24),

          // --- Question Header & Mark for Review Button ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentIndex + 1} of ${_questions.length}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              OutlinedButton.icon(
                icon: Icon(
                  isMarked ? Icons.flag : Icons.flag_outlined,
                  color: isMarked ? Colors.orange : Colors.grey[600],
                  size: 20,
                ),
                label: Text(
                  isMarked ? 'Marked for Review' : 'Mark for Review',
                  style: TextStyle(
                    color: isMarked ? Colors.orange : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isMarked ? Colors.orange : Colors.grey[400]!,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    if (isMarked) {
                      _markedForReview.remove(currentQuestion.id);
                    } else {
                      _markedForReview.add(currentQuestion.id);
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            currentQuestion.text,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),

          ...currentQuestion.options.map((option) {
            final isSelected = _answers[currentQuestion.id] == option;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                mouseCursor: SystemMouseCursors.click,
                onTap: () =>
                    setState(() => _answers[currentQuestion.id] = option),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue[50] : Colors.white,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey[300]!,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          option,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _currentIndex > 0
                    ? () => setState(() => _currentIndex--)
                    : null,
                child: const Text('Previous'),
              ),
              if (_currentIndex < _questions.length - 1)
                ElevatedButton(
                  onPressed: () => setState(() => _currentIndex++),
                  child: const Text('Next'),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _submitExam,
                  child: const Text('Submit Exam'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isFrozen ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isFrozen ? 'PENALTY LOCKOUT' : 'SECURE EXAM ACTIVE',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!_isLoading && !_isFrozen)
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _formattedTime,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
          ],
        ),
        backgroundColor: _isFrozen ? Colors.black87 : Colors.blueGrey,
        automaticallyImplyLeading: false,
      ),
      body: _isFrozen
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_clock,
                    size: 80,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Security Violation!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'You left the secure environment.\nThe exam is frozen for:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _formattedPenaltyTime,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _questions.isEmpty
                  ? const Center(child: Text("No questions found."))
                  : _buildExamContent(),
            ),
    );
  }
}
