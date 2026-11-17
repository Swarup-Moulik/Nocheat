import 'package:flutter/material.dart';

class QuestionFormState {
  String id = DateTime.now().millisecondsSinceEpoch.toString();
  TextEditingController textController = TextEditingController();
  TextEditingController marksController = TextEditingController(text: '1');
  List<TextEditingController> optionControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  int correctOptionIndex = 0;
}
