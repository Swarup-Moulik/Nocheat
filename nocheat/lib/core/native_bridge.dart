import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

typedef InitLockdownC = ffi.Int32 Function();
typedef InitLockdownDart = int Function();

class NativeBridge {
  static final NativeBridge _instance = NativeBridge._internal();
  InitLockdownDart? _initializeLockdown;

  // Define the communication channel for Android
  static const MethodChannel _androidChannel = MethodChannel(
    'nocheat.exam/lockdown',
  );

  // Singleton factory
  factory NativeBridge() {
    return _instance;
  }

  NativeBridge._internal() {
    if (Platform.isWindows) {
      try {
        final dylib = ffi.DynamicLibrary.executable();
        _initializeLockdown = dylib
            .lookup<ffi.NativeFunction<InitLockdownC>>('initialize_lockdown')
            .asFunction<InitLockdownDart>();
      } catch (e) {
        debugPrint("FFI Initialization failed: $e");
      }
    }
  }

  // Updated to Future<bool> to support asynchronous Android channels
  Future<bool> triggerLockdown() async {
    if (Platform.isWindows && _initializeLockdown != null) {
      // Returns true if C++ executed successfully
      return _initializeLockdown!() == 1;
    }

    if (Platform.isAndroid) {
      try {
        // Instruct Kotlin to pin the screen
        final bool result = await _androidChannel.invokeMethod('startLockTask');
        return result;
      } on PlatformException catch (e) {
        debugPrint("Failed to start Lock Task: '${e.message}'.");
        return false;
      }
    }

    return false;
  }

  Future<bool> releaseLockdown() async {
    if (Platform.isAndroid) {
      try {
        final bool result = await _androidChannel.invokeMethod('stopLockTask');
        return result;
      } on PlatformException catch (e) {
        debugPrint("Failed to stop Lock Task: '${e.message}'.");
        return false;
      }
    }
    // Windows handles its own release when the child process exits
    return true; 
  }
}