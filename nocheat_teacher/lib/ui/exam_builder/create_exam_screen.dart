import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:csv/csv.dart';

import '../../core/api_client.dart';
import '../../models/exam.dart';

class CreateExamScreen extends StatefulWidget {
  const CreateExamScreen({super.key});

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  final _titleController = TextEditingController();

  // Timing State
  int _durationHours = 1;
  int _durationMinutes = 0;
  int _penaltyMinutes = 1;
  int _penaltySeconds = 0;

  DateTime? _startTime;
  DateTime? _endTime;

  List<dynamic> _assignments = [];
  String? _selectedClassId;
  String? _selectedSubjectId;

  List<QuestionFormState> _questions = [QuestionFormState()];

  bool _isLoadingData = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    final assignments = await ApiClient.fetchTeacherAssignments();
    setState(() {
      _assignments = assignments;
      _isLoadingData = false;
    });
  }

  Future<void> _pickDateTime(bool isStart) async {
    DateTime initialDate = DateTime.now();
    DateTime firstDate = DateTime.now().subtract(const Duration(days: 1));

    if (!isStart && _startTime != null) {
      initialDate = _startTime!;
      firstDate = _startTime!;
    }

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    if (!mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    DateTime selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!isStart && _startTime != null && selected.isBefore(_startTime!)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End time cannot be earlier than Start time.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      if (isStart) {
        _startTime = selected;
        if (_endTime != null && _endTime!.isBefore(_startTime!)) {
          _endTime = null;
        }
      } else {
        _endTime = selected;
      }
    });
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Select Date & Time';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // --- CSV Import Logic with (Ans) marker ---
  Future<void> _importQuestionsFromCSV() async {
    try {
      // 1. Define the file type we want to accept
      const XTypeGroup csvTypeGroup = XTypeGroup(
        label: 'CSVs',
        extensions: <String>['csv'],
      );

      // 2. Open the native Windows file dialog
      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[csvTypeGroup],
      );

      if (file != null) {
        // 3. Read the file (file_selector handles desktop/web paths automatically)
        final String csvString = await file.readAsString();

        // 4. Parse it using your existing CSV converter
        final rowsAsListOfValues = csv.decode(csvString);

        if (rowsAsListOfValues.isEmpty) return;

        List<QuestionFormState> importedQuestions = [];

        int startIndex = 0;
        if (rowsAsListOfValues[0][0].toString().toLowerCase().contains(
          'question',
        )) {
          startIndex = 1;
        }

        for (int i = startIndex; i < rowsAsListOfValues.length; i++) {
          var row = rowsAsListOfValues[i];
          if (row.length < 5) continue;

          QuestionFormState qState = QuestionFormState();
          qState.textController.text = row[0].toString();

          int correctIndex = 0;
          for (int opt = 0; opt < 4; opt++) {
            if (row.length > opt + 1) {
              String optionText = row[opt + 1].toString();

              if (optionText.trim().toLowerCase().startsWith('(ans)')) {
                correctIndex = opt;
                optionText = optionText.trim().substring(5).trim();
              }

              qState.optionControllers[opt].text = optionText;
            }
          }
          qState.correctOptionIndex = correctIndex;

          if (row.length > 5) {
            qState.marksController.text = row[5].toString();
          } else {
            qState.marksController.text = "1";
          }

          importedQuestions.add(qState);
        }

        if (importedQuestions.isNotEmpty) {
          setState(() {
            if (_questions.length == 1 &&
                _questions[0].textController.text.isEmpty) {
              _questions = importedQuestions;
            } else {
              _questions.addAll(importedQuestions);
            }
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Successfully imported ${importedQuestions.length} questions!',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error parsing CSV file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitExam() async {
    if (_titleController.text.isEmpty ||
        _selectedClassId == null ||
        _selectedSubjectId == null ||
        _startTime == null ||
        _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill out all fields, including the Time Window.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_durationHours == 0 && _durationMinutes == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Duration must be greater than 0.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_penaltyMinutes == 0 && _penaltySeconds == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Penalty must be greater than 0.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    int calculatedTotalMarks = 0;
    List formattedQuestions = _questions.map((q) {
      int marks = int.tryParse(q.marksController.text) ?? 1;
      calculatedTotalMarks += marks;
      List<String> options = q.optionControllers.map((c) => c.text).toList();
      return {
        "id": "q_${q.id}",
        "text": q.textController.text,
        "options": options,
        "correct_answer": options[q.correctOptionIndex],
        "marks": marks,
      };
    }).toList();

    final payload = {
      "institute_id": ApiClient.currentInstituteId,
      "teacher_id": ApiClient.currentTeacherId,
      "title": _titleController.text,
      "subject_id": _selectedSubjectId,
      "class_id": _selectedClassId,
      "total_marks": calculatedTotalMarks,
      "duration_minutes": (_durationHours * 60) + _durationMinutes,
      "penalty_seconds": (_penaltyMinutes * 60) + _penaltySeconds,
      "start_time": _startTime!.toUtc().toIso8601String(),
      "end_time": _endTime!.toUtc().toIso8601String(),
      "questions": formattedQuestions,
    };

    final examId = await ApiClient.createExam(payload);

    setState(() => _isSubmitting = false);

    if (!mounted) return;
    if (examId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exam Created! ID: $examId'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _titleController.clear();
        _selectedClassId = null;
        _selectedSubjectId = null;
        _startTime = null;
        _endTime = null;
        _durationHours = 1;
        _durationMinutes = 0;
        _penaltyMinutes = 1;
        _penaltySeconds = 0;
        _questions.clear();
        _questions.add(QuestionFormState());
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create exam.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) return const Center(child: CircularProgressIndicator());

    final Map<String, String> uniqueClasses = {};
    for (var a in _assignments) {
      uniqueClasses[a['class_id']] = a['class_name'];
    }

    final Map<String, String> availableSubjects = {};
    if (_selectedClassId != null) {
      for (var a in _assignments) {
        if (a['class_id'] == _selectedClassId) {
          availableSubjects[a['subject_id']] = a['subject_name'];
        }
      }
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TabBar(
            labelColor: Colors.blueGrey,
            indicatorColor: Colors.blueGrey,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                icon: Icon(Icons.info_outline),
                text: 'Exam Details & Timing',
              ),
              Tab(icon: Icon(Icons.quiz_outlined), text: 'Questions Setup'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDetailsTab(uniqueClasses, availableSubjects),
                _buildQuestionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(
    Map<String, String> uniqueClasses,
    Map<String, String> availableSubjects,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Exam Details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Exam Title',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedClassId,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Class',
                    border: OutlineInputBorder(),
                  ),
                  items: uniqueClasses.entries
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.key,
                          child: Text(c.value),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() {
                    _selectedClassId = val;
                    _selectedSubjectId = null;
                  }),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedSubjectId,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Subject',
                    border: OutlineInputBorder(),
                  ),
                  items: availableSubjects.entries
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.key,
                          child: Text(s.value),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedSubjectId = val),
                  hint: Text(
                    availableSubjects.isEmpty
                        ? 'Select a Class first'
                        : 'Select Subject',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Settings & Timing',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDateTime(true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Available From',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_formatDate(_startTime)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDateTime(false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Available Until',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_formatDate(_endTime)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Exam Duration (HH:MM)',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _durationHours,
                          isDense: true,
                          items: List.generate(
                            6,
                            (i) =>
                                DropdownMenuItem(value: i, child: Text('$i h')),
                          ),
                          onChanged: (val) =>
                              setState(() => _durationHours = val!),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          ':',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _durationMinutes,
                          isDense: true,
                          items: List.generate(
                            12,
                            (i) => DropdownMenuItem(
                              value: i * 5,
                              child: Text('${i * 5} m'),
                            ),
                          ),
                          onChanged: (val) =>
                              setState(() => _durationMinutes = val!),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Penalty Lockout (MM:SS)',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _penaltyMinutes,
                          isDense: true,
                          items: List.generate(
                            6,
                            (i) =>
                                DropdownMenuItem(value: i, child: Text('$i m')),
                          ),
                          onChanged: (val) =>
                              setState(() => _penaltyMinutes = val!),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          ':',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _penaltySeconds,
                          isDense: true,
                          items: List.generate(
                            6,
                            (i) => DropdownMenuItem(
                              value: i * 10,
                              child: Text('${i * 10} s'),
                            ),
                          ),
                          onChanged: (val) =>
                              setState(() => _penaltySeconds = val!),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsTab() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Configure Questions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _importQuestionsFromCSV,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import CSV'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () =>
                        setState(() => _questions.add(QuestionFormState())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Question'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                return _buildQuestionCard(_questions[index], index);
              },
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitExam,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.publish),
              label: const Text('Publish Exam'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[900],
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(QuestionFormState qState, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                if (_questions.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => setState(() => _questions.removeAt(index)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: qState.textController,
                    decoration: const InputDecoration(
                      labelText: 'Question Text',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: qState.marksController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Marks',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(4, (optIndex) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Radio<int>(
                      value: optIndex,
                      groupValue: qState.correctOptionIndex,
                      activeColor: Colors.blueGrey,
                      onChanged: (val) =>
                          setState(() => qState.correctOptionIndex = val!),
                    ),
                    Expanded(
                      child: TextField(
                        controller: qState.optionControllers[optIndex],
                        decoration: InputDecoration(
                          labelText:
                              'Option ${String.fromCharCode(65 + optIndex)}',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
