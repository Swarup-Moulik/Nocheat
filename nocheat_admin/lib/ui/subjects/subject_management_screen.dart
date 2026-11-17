import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/subject.dart';
import '../../models/class_group.dart';

class SubjectManagementScreen extends StatefulWidget {
  const SubjectManagementScreen({super.key});

  @override
  State<SubjectManagementScreen> createState() =>
      _SubjectManagementScreenState();
}

class _SubjectManagementScreenState extends State<SubjectManagementScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  String? _selectedClassId;
  bool _isSubmitting = false;

  List<SubjectModel> _subjects = [];
  List<ClassModel> _classes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final subjects = await ApiClient.fetchSubjects();
      final classes = await ApiClient.fetchClasses();
      setState(() {
        _subjects = subjects;
        _classes = classes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("Error loading data: $e");
    }
  }

  Future<void> _submitSubject() async {
    if (_codeController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select a Class.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final success = await ApiClient.createSubject(
      _codeController.text,
      _nameController.text,
      _selectedClassId!,
    );
    setState(() => _isSubmitting = false);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subject Added'),
          backgroundColor: Colors.green,
        ),
      );
      _codeController.clear();
      _nameController.clear();
      setState(() => _selectedClassId = null);
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add subject. Code may already exist.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- NEW: Confirmation Modal ---
  void _confirmDeleteSubject(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to permanently delete this subject?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSubject(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Yes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubject(String id) async {
    final success = await ApiClient.deleteSubject(id);
    if (success) _loadData();
  }

  String _getClassName(String? classId) {
    if (classId == null || classId.isEmpty) return "N/A";
    try {
      return _classes.firstWhere((c) => c.id == classId).name;
    } catch (e) {
      return "Unknown";
    }
  }

  @override
  Widget build(BuildContext context) {
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
                icon: Icon(Icons.add_circle_outline),
                text: 'Add New Subject',
              ),
              Tab(icon: Icon(Icons.list_alt), text: 'Subject List'),
            ],
          ),
          Expanded(
            child: TabBarView(children: [_buildAddNewTab(), _buildListTab()]),
          ),
        ],
      ),
    );
  }

  Widget _buildAddNewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Subject Code (e.g. CS101)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Subject Name',
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
                    labelText: 'Assign to Class',
                    border: OutlineInputBorder(),
                  ),
                  items: _classes
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedClassId = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            width: 200,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitSubject,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[900],
                foregroundColor: Colors.white,
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
                  : const Text('Create Subject'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTab() {
    final filtered = _subjects.where((s) {
      final query = _searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(query) ||
          s.code.toLowerCase().contains(query) ||
          _getClassName(s.classId).toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search by Name, Code, or Class',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const Spacer(
                flex: 2,
              ), // Keep search bar width reasonable on desktop
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
              ? const Center(child: Text('No subjects found.'))
              : SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Code')),
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Class')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filtered
                        .map(
                          (sub) => DataRow(
                            cells: [
                              DataCell(Text(sub.code)),
                              DataCell(Text(sub.name)),
                              DataCell(Text(_getClassName(sub.classId))),
                              DataCell(
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _confirmDeleteSubject(
                                    sub.id,
                                  ), // <-- Updated
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
      ],
    );
  }
}
