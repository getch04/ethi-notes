import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ElevenLabsApiService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://api.elevenlabs.io/v1/speech-to-text';

  Future<String?> transcribe({
    required String filePath,
    required String languageCode,
  }) async {
    final String apiKey =
        dotenv.env['ELEVENLABS_API_KEY'] ??
        const String.fromEnvironment('ELEVENLABS_API_KEY');

    if (apiKey.isEmpty) {
      final msg =
          'ElevenLabs API Key is missing. Please check your .env or --dart-define.';
      debugPrint("ElevenLabsApiService: $msg");
      throw Exception(msg);
    }

    try {
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: 'audio.wav'),
        'model_id': 'scribe_v1',
        'language_code': languageCode,
      });

      final response = await _dio.post(
        _baseUrl,
        data: formData,
        options: Options(headers: {'xi-api-key': apiKey}),
      );

      if (response.statusCode == 200) {
        return response.data['text'] as String?;
      } else {
        final msg = 'Failed to transcribe: ${response.statusMessage}';
        debugPrint("ElevenLabsApiService: $msg");
        throw Exception(msg);
      }
    } catch (e, stackTrace) {
      if (e is DioException) {
        final msg = 'API Error: ${e.response?.data ?? e.message}';
        debugPrint("ElevenLabsApiService: $msg");
        debugPrint("DioException: $e");
        debugPrint("Stack trace: $stackTrace");
        throw Exception(msg);
      }
      debugPrint("ElevenLabsApiService: $e");
      debugPrint("Stack trace: $stackTrace");
      rethrow;
    }
  }
}
