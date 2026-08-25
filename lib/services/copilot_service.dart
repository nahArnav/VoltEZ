import 'dart:convert';
import 'package:http/http.dart' as http;

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

class CopilotService {
  static const String baseUrl = 'https://api.yourdomain.com/v1';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // 'Authorization': 'Bearer <YOUR_JWT_TOKEN>',
      };

  Future<String> queryCopilot({
    required String prompt,
    List<Map<String, String>>? conversationHistory,
  }) async {
    final uri = Uri.parse('$baseUrl/businesses/me/copilot-query');

    final payload = {
      'query': prompt,
      if (conversationHistory != null && conversationHistory.isNotEmpty)
        'history': conversationHistory,
    };

    final response = await http.post(
      uri,
      headers: _headers,
      body: json.encode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      // Handles either { "response": "..." } or { "reply": "..." } or { "message": "..." }
      return data['response'] ?? data['reply'] ?? data['message'] ?? 'No response received from AI.';
    } else {
      throw Exception('Server error: (${response.statusCode}) - ${response.reasonPhrase}');
    }
  }
}