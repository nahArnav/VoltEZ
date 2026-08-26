import 'dart:convert';
import '../services/api_client.dart';

class CopilotMessage {
  final String text;
  final bool isAi;
  final DateTime timestamp;

  CopilotMessage({
    required this.text,
    required this.isAi,
    required this.timestamp,
  });

  factory CopilotMessage.ai(String text) => CopilotMessage(
        text: text,
        isAi: true,
        timestamp: DateTime.now(),
      );

  factory CopilotMessage.user(String text) => CopilotMessage(
        text: text,
        isAi: false,
        timestamp: DateTime.now(),
      );
}

/// Copilot AI service using the centralized ApiClient with JWT auth.
///
/// NOTE: The backend endpoint for copilot queries does not exist yet.
/// This service is wired up correctly so it will work once the endpoint
/// is implemented on the backend.
class CopilotService {
  final _api = ApiClient.instance;

  Future<String> queryCopilot({
    required String prompt,
    List<Map<String, String>>? conversationHistory,
  }) async {
    final payload = <String, dynamic>{
      'query': prompt,
      if (conversationHistory != null && conversationHistory.isNotEmpty)
        'history': conversationHistory,
    };

    try {
      final response = await _api.post(
        '/businesses/me/copilot-query',
        data: payload,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return data['response'] ??
            data['reply'] ??
            data['message'] ??
            'No response received from AI.';
      } else {
        throw Exception(
            'Server error: (${response.statusCode})');
      }
    } catch (e) {
      // The copilot endpoint is not yet implemented on the backend.
      // Return a helpful fallback message instead of crashing.
      return 'The AI Copilot is not yet available. This feature is coming soon.';
    }
  }
}