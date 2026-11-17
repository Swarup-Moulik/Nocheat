import 'package:flutter/material.dart';

import '../../core/api_client.dart'; // <-- Added import
import '../auth/login_screen.dart'; // <-- Added import
import '../users/user_management_screen.dart';
import '../subjects/subject_management_screen.dart';
import '../classes/class_management_screen.dart';
import '../assignments/assignment_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const UserManagementScreen(),
    const SubjectManagementScreen(),
    const ClassManagementScreen(),
    const AssignmentManagementScreen(),
  ];

  void _handleLogout() {
    ApiClient.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false, // Destroy the entire navigation stack
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NoCheat Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: Colors.blueGrey[50],
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) =>
                setState(() => _selectedIndex = index),
            extended: true,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people, color: Colors.blueGrey),
                label: Text('Users'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.book_outlined),
                selectedIcon: Icon(Icons.book, color: Colors.blueGrey),
                label: Text('Subjects'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.class_outlined),
                selectedIcon: Icon(Icons.class_, color: Colors.blueGrey),
                label: Text('Classes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.link_outlined),
                selectedIcon: Icon(Icons.link, color: Colors.blueGrey),
                label: Text('Link Teacher'),
              ),
            ],
            // --- ADDED LOGOUT BUTTON ---
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    tooltip: 'Log Out',
                    onPressed: _handleLogout,
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}
