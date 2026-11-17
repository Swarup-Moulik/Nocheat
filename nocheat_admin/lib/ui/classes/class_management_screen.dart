import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/class_group.dart';

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  final _nameController = TextEditingController();
  bool _isSubmitting = false;

  List<ClassModel> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    final classes = await ApiClient.fetchClasses();
    setState(() {
      _classes = classes;
      _isLoading = false;
    });
  }

  Future<void> _submitClass() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isSubmitting = true);
    final success = await ApiClient.createClass(_nameController.text);
    setState(() => _isSubmitting = false);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Class Added'),
          backgroundColor: Colors.green,
        ),
      );
      _nameController.clear();
      _loadClasses();
    }
  }

  // --- NEW: Confirmation Modal ---
  void _confirmDeleteClass(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to permanently delete this class?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteClass(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Yes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClass(String id) async {
    final success = await ApiClient.deleteClass(id);
    if (success) _loadClasses();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.blueGrey,
            indicatorColor: Colors.blueGrey,
            tabs: [
              Tab(icon: Icon(Icons.add_circle_outline), text: 'Add New Class'),
              Tab(icon: Icon(Icons.list_alt), text: 'Class List'),
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
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 400,
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Class Name (e.g. BCA4G)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitClass,
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
                : const Text('Create Class'),
          ),
        ],
      ),
    );
  }

  Widget _buildListTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Class Name')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _classes
                        .map(
                          (cls) => DataRow(
                            cells: [
                              DataCell(Text(cls.name)),
                              DataCell(
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _confirmDeleteClass(
                                    cls.id,
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
