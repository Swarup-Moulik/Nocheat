import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/user.dart';
import '../../models/subject.dart';
import '../../models/class_group.dart';
import '../../models/assignment.dart';

class AssignmentManagementScreen extends StatefulWidget {
  const AssignmentManagementScreen({super.key});

  @override
  State<AssignmentManagementScreen> createState() =>
      _AssignmentManagementScreenState();
}

class _AssignmentManagementScreenState
    extends State<AssignmentManagementScreen> {
  List<UserModel> _teachers = [];
  List<SubjectModel> _subjects = [];
  List<ClassModel> _classes = [];
  List<AssignmentModel> _assignments = [];

  String? _selectedTeacherId;
  String? _selectedSubjectId;
  String? _selectedClassId;

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    final users = await ApiClient.fetchUsers();
    final subjects = await ApiClient.fetchSubjects();
    final classes = await ApiClient.fetchClasses();
    final assignments = await ApiClient.fetchAssignments();

    setState(() {
      _teachers = users.where((u) => u.role == 'teacher').toList();
      _subjects = subjects;
      _classes = classes;
      _assignments = assignments;
      _isLoading = false;
    });
  }

  Future<void> _submitAssignment() async {
    if (_selectedClassId == null ||
        _selectedSubjectId == null ||
        _selectedTeacherId == null)
      return;

    setState(() => _isSubmitting = true);
    final success = await ApiClient.assignTeacher(
      _selectedClassId!,
      _selectedSubjectId!,
      _selectedTeacherId!,
    );
    setState(() => _isSubmitting = false);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teacher Linked Successfully'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _selectedTeacherId = null;
        _selectedSubjectId = null;
        _selectedClassId = null;
      });
      _loadAllData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to link. Mapping may already exist.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- NEW: Confirmation Modal ---
  void _confirmDeleteAssignment(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text(
          'Do you want to permanently delete this teacher assignment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAssignment(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Yes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAssignment(String id) async {
    final success = await ApiClient.deleteAssignment(id);
    if (success) _loadAllData();
  }

  String _getClassName(String id) => _classes
      .firstWhere(
        (c) => c.id == id,
        orElse: () => ClassModel(id: '', name: 'Unknown'),
      )
      .name;
  String _getSubjectName(String id) => _subjects
      .firstWhere(
        (s) => s.id == id,
        orElse: () => SubjectModel(id: '', code: '', name: 'Unknown'),
      )
      .name;
  String _getTeacherName(String id) => _teachers
      .firstWhere(
        (t) => t.id == id,
        orElse: () => UserModel(id: '', name: 'Unknown', email: '', role: ''),
      )
      .name;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.blueGrey,
            indicatorColor: Colors.blueGrey,
            tabs: [
              Tab(icon: Icon(Icons.link), text: 'Link Teacher'),
              Tab(icon: Icon(Icons.list_alt), text: 'Active Links'),
            ],
          ),
          Expanded(
            child: TabBarView(children: [_buildLinkTab(), _buildListTab()]),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTab() {
    final availableSubjects = _selectedClassId == null
        ? <SubjectModel>[]
        : _subjects.where((s) => s.classId == _selectedClassId).toList();

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedTeacherId,
                  decoration: const InputDecoration(
                    labelText: 'Select Teacher',
                    border: OutlineInputBorder(),
                  ),
                  items: _teachers
                      .map(
                        (t) =>
                            DropdownMenuItem(value: t.id, child: Text(t.name)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedTeacherId = val),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedClassId,
                  decoration: const InputDecoration(
                    labelText: 'Select Class',
                    border: OutlineInputBorder(),
                  ),
                  items: _classes
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
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
                    labelText: 'Select Subject',
                    border: OutlineInputBorder(),
                  ),
                  items: availableSubjects
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.code} - ${s.name}'),
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitAssignment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey[900],
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 50),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text('Create Link'),
          ),
        ],
      ),
    );
  }

  Widget _buildListTab() {
    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Class')),
          DataColumn(label: Text('Subject')),
          DataColumn(label: Text('Teacher')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _assignments.map((assignment) {
          return DataRow(
            cells: [
              DataCell(Text(_getClassName(assignment.classId))),
              DataCell(Text(_getSubjectName(assignment.subjectId))),
              DataCell(Text(_getTeacherName(assignment.teacherId))),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () =>
                      _confirmDeleteAssignment(assignment.id), // <-- Updated
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
