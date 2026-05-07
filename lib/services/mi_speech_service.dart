import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MiSpeechService {
  static const MethodChannel _channel = MethodChannel('bsh_smart/mi_speech');

  static Future<Map<String, dynamic>> getSpeechSupport() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const {
        'available': false,
        'manufacturer': 'unknown',
      };
    }
    try {
      final data = await _channel.invokeMethod<dynamic>('getSpeechSupport');
      if (data is Map) {
        return {
          'available': data['available'] == true,
          'manufacturer': (data['manufacturer'] ?? 'unknown').toString(),
        };
      }
    } catch (_) {}
    return const {
      'available': false,
      'manufacturer': 'unknown',
    };
  }

  static Future<String?> recognizeOnce({
    String locale = 'zh_CN',
    String prompt = 'Speak now',
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final result = await _channel.invokeMethod<String>(
        'recognizeOnce',
        {
          'locale': locale,
          'prompt': prompt,
        },
      );
      return result?.trim().isEmpty == true ? null : result?.trim();
    } catch (_) {
      return null;
    }
  }
}
