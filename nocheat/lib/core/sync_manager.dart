import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class SyncManager {
  static const String _queueKey = 'offline_telemetry_queue';

  // 1. Save failed network requests to local storage
  static Future<void> queueRequest(
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];

    queue.add(jsonEncode({'endpoint': endpoint, 'payload': payload}));
    await prefs.setStringList(_queueKey, queue);
    debugPrint("Saved to offline queue. Total pending: ${queue.length}");
  }

  // 2. Attempt to send all locally saved requests
  static Future<void> syncOfflineData(String backendUrl) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];

    if (queue.isEmpty) return;
    debugPrint("Attempting to sync ${queue.length} offline events...");

    List<String> remainingQueue = [];

    for (String item in queue) {
      final data = jsonDecode(item);
      try {
        final response = await http.post(
          Uri.parse('$backendUrl${data['endpoint']}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data['payload']),
        );

        // If the server rejects it (e.g. 500 error), keep it in the queue to try again
        if (response.statusCode != 200 && response.statusCode != 201) {
          remainingQueue.add(item);
        }
      } catch (e) {
        // Network still down, keep in queue
        remainingQueue.add(item);
      }
    }

    await prefs.setStringList(_queueKey, remainingQueue);
    debugPrint("Sync complete. Remaining pending: ${remainingQueue.length}");
  }
}
