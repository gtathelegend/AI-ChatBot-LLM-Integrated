import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

class LlmService {
  final String baseUrl; // e.g. http://192.168.1.5:8000
  final String modelName;

  LlmService({
    required this.baseUrl,
    required this.modelName,
  });

  Future<String> sendMessage({
    required String message,
    List<Attachment> attachments = const [],
  }) async {
    final uri = Uri.parse('$baseUrl/chat');

    // For prototype: send attachment metadata only
    final attachmentPayload = <Map<String, dynamic>>[];
    for (final att in attachments) {
      final file = File(att.path);
      final exists = await file.exists();
      if (!exists) continue;

      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);
      attachmentPayload.add({
        "name": att.name,
        "mime_type": att.mimeType,
        "data_base64": base64Data,
      });
    }

    final body = jsonEncode({
      "message": message,
      "model": modelName,
      "attachments": attachmentPayload,
    });

    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (res.statusCode != 200) {
      throw Exception('LLM error: ${res.statusCode} - ${res.body}');
    }

    final data = jsonDecode(res.body);
    return data["reply"] ?? "No reply field in response.";
  }
}
