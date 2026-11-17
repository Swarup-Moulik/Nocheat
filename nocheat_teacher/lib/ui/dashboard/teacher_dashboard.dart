import 'package:flutter/material.dart';

import '../../main.dart'; // <-- Import the themeNotifier
import '../../core/api_client.dart';
import '../auth/login_screen.dart';
import '../exam_builder/create_exam_screen.dart';
import '../live_monitor/live_proctor_screen.dart';
import '../results/results_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const CreateExamScreen(),
    const LiveProctorScreen(),
    const ResultsScreen(),
  ];

  void _handleLogout() {
    ApiClient.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NoCheat Teacher Command Center',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[900],
        foregroundColor: Colors.white,
        actions: [
          // --- Theme Toggle Button ---
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (_, ThemeMode currentMode, __) {
              return IconButton(
                icon: Icon(
                  currentMode == ThemeMode.light
                      ? Icons.dark_mode
                      : Icons.light_mode,
                ),
                tooltip: 'Toggle Theme',
                onPressed: () {
                  themeNotifier.value = currentMode == ThemeMode.light
                      ? ThemeMode.dark
                      : ThemeMode.light;
                },
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: isDark ? Colors.grey[850] : Colors.blueGrey[50],
            unselectedIconTheme: IconThemeData(
              color: isDark ? Colors.white54 : Colors.black54,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
            ),
            selectedIconTheme: const IconThemeData(color: Colors.blueGrey),
            selectedLabelTextStyle: const TextStyle(
              color: Colors.blueGrey,
              fontWeight: FontWeight.bold,
            ),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) =>
                setState(() => _selectedIndex = index),
            extended: true,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.add_task),
                label: Text('Create Exam'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.monitor_heart),
                label: Text('Live Monitor'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart),
                label: Text('Results & Grades'),
              ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
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
