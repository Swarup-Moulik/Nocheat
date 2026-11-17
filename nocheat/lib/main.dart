import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'ui/auth/login_screen.dart';
import 'ui/exam/exam_screen.dart';

// --- NEW: Global Theme Notifier (Defaults to Light) ---
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isSecureMode = args.contains('--secure');
  String launchExamId = "mock_exam_101";

  if (isSecureMode) {
    final prefs = await SharedPreferences.getInstance();
    launchExamId = prefs.getString('active_exam_id') ?? "mock_exam_101";

    ApiClient.currentStudentId = prefs.getString('active_student_id') ?? '';
    ApiClient.currentInstituteId = prefs.getString('active_institute_id') ?? '';
  }

  runApp(MyApp(isSecureMode: isSecureMode, examId: launchExamId));
}

class MyApp extends StatelessWidget {
  final bool isSecureMode;
  final String examId;

  const MyApp({super.key, required this.isSecureMode, required this.examId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'NoCheat',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          // --- LIGHT THEME ---
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blueGrey,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          // --- DARK THEME ---
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blueGrey,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: isSecureMode ? ExamScreen(examId: examId) : const LoginScreen(),
        );
      },
    );
  }
}
