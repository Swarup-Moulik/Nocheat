import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/user.dart';
import '../../models/class_group.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentIdController = TextEditingController();

  String _selectedRole = 'teacher';
  String? _selectedClassId;

  bool _isSubmitting = false;

  List<UserModel> _users = [];
  List<ClassModel> _classes = [];
  bool _isLoading = true;
  String _roleFilter = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final users = await ApiClient.fetchUsers();
      final classes = await ApiClient.fetchClasses();
      setState(() {
        _users = users;
        _classes = classes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("Error loading data: $e");
    }
  }

  Future<void> _submitUser() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) return;

    if (_selectedRole == 'student' &&
        (_studentIdController.text.isEmpty || _selectedClassId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a Student ID and select a Class.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await ApiClient.createUser(
      _nameController.text,
      _emailController.text,
      _selectedRole,
      studentRoll: _selectedRole == 'student'
          ? _studentIdController.text
          : null,
      classId: _selectedRole == 'student' ? _selectedClassId : null,
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User Provisioned'),
          backgroundColor: Colors.green,
        ),
      );
      _nameController.clear();
      _emailController.clear();
      _studentIdController.clear();
      setState(() => _selectedClassId = null);
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed. Ensure backend is running and email is unique.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDeleteUser(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to permanently delete this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Yes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String id) async {
    final success = await ApiClient.deleteUser(id);
    if (success) {
      _loadData();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete user'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- NEW: Method to handle Class reassignment via Dropdown ---
  Future<void> _updateStudentClass(String userId, String newClassId) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Updating class...'),
        duration: Duration(milliseconds: 500),
      ),
    );

    final success = await ApiClient.updateUserClass(userId, newClassId);

    if (!mounted) return;

    if (success) {
      setState(() {
        final userIndex = _users.indexWhere((u) => u.id == userId);
        if (userIndex != -1) {
          _users[userIndex].classId = newClassId;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Class updated successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update class. Check connection.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
              Tab(icon: Icon(Icons.add_circle_outline), text: 'Add New'),
              Tab(icon: Icon(Icons.list_alt), text: 'User List'),
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
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'System Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                  ],
                  onChanged: (val) => setState(() {
                    _selectedRole = val!;
                    if (_selectedRole != 'student') {
                      _studentIdController.clear();
                      _selectedClassId = null;
                    }
                  }),
                ),
              ),
            ],
          ),

          if (_selectedRole == 'student') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _studentIdController,
                    decoration: const InputDecoration(
                      labelText: 'Student ID',
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
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedClassId = val),
                  ),
                ),
                const SizedBox(width: 16),
                const Spacer(),
              ],
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            width: 200,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitUser,
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
                  : const Text('Create User'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTab() {
    var filteredUsers = _roleFilter == 'All'
        ? _users
        : _users.where((u) => u.role == _roleFilter.toLowerCase()).toList();

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredUsers = filteredUsers.where((u) {
        final nameMatch = u.name.toLowerCase().contains(query);
        final emailMatch = u.email.toLowerCase().contains(query);
        final idMatch = (u.studentRoll ?? '').toLowerCase().contains(query);
        final classMatch = _getClassName(u.classId)
            .toLowerCase()
            .contains(query);

        return nameMatch || emailMatch || idMatch || classMatch;
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Text(
                'Filter by Role: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _roleFilter,
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All Users')),
                  DropdownMenuItem(value: 'teacher', child: Text('Teachers')),
                  DropdownMenuItem(value: 'student', child: Text('Students')),
                ],
                onChanged: (val) => setState(() => _roleFilter = val!),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search by Name, Email, Student ID, or Class',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredUsers.isEmpty
              ? const Center(child: Text('No users found.'))
              : SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Student ID')),
                      DataColumn(label: Text('Class')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filteredUsers.map((user) {
                      return DataRow(
                        cells: [
                          DataCell(Text(user.name)),
                          DataCell(Text(user.email)),
                          DataCell(Text(user.role.toUpperCase())),
                          DataCell(
                            Text(
                              user.role == 'student'
                                  ? (user.studentRoll ?? "-")
                                  : '-',
                            ),
                          ),
                          // --- NEW: Editable Dropdown for Student Classes ---
                          DataCell(
                            user.role == 'student'
                                ? DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: user.classId,
                                      hint: const Text('Assign Class'),
                                      items: _classes
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c.id,
                                              child: Text(c.name),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (newClassId) {
                                        if (newClassId != null &&
                                            newClassId != user.classId) {
                                          _updateStudentClass(
                                            user.id,
                                            newClassId,
                                          );
                                        }
                                      },
                                    ),
                                  )
                                : const Text('-'),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              tooltip: 'Delete User',
                              onPressed: () => _confirmDeleteUser(user.id),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}
