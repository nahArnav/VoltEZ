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

/// Copilot AI service using the live sponsor endpoint.
class CopilotService {
  final _api = ApiClient.instance;

  Future<String> queryCopilot({
    required String prompt,
    List<Map<String, String>>? conversationHistory,
  }) async {
    final payload = <String, dynamic>{
      'prompt': prompt,
      'context': 'host',
    };

    try {
      final response = await _api.post(
        '/sponsors/copilot',
        data: payload,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return data['advice'] ??
            'No response received from AI.';
      } else {
        throw Exception(
            'Server error: (${response.statusCode})');
      }
    } catch (_) {
      return 'The AI Copilot is unavailable right now. Please try again shortly.';
    }
  }
}
