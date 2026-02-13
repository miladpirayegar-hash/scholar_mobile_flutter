import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../models/session.dart';
import '../../config/api_config.dart';

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  // -----------------------------
  // Sessions count (Explore)
  // -----------------------------
  Future<int> fetchSessionCount() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/sessions/count'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch session count');
    }

    final data = jsonDecode(response.body);
    return (data['count'] as num).toInt();
  }

  // -----------------------------
  // Upload recording
  // -----------------------------
  Future<String> uploadSessionAudio({
    String? audioPath,
    Uint8List? audioBytes,
    String filename = 'recording.m4a',
    String? eventId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/sessions');
    final request = http.MultipartRequest('POST', uri);
    if (eventId != null && eventId.isNotEmpty) {
      request.fields['eventId'] = eventId;
    }
    if (audioBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: filename,
          contentType: MediaType('audio', 'm4a'),
        ),
      );
    } else if (audioPath != null && audioPath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioPath,
          contentType: MediaType('audio', 'm4a'),
        ),
      );
    } else {
      throw ArgumentError(
        'Provide either audioPath or audioBytes for uploadSessionAudio.',
      );
    }

    final response = await request.send();

    if (response.statusCode != 201) {
      final body = await response.stream.bytesToString();
      throw Exception(
        'Session upload failed (${response.statusCode}): $body',
      );
    }
    final body = await response.stream.bytesToString();
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final id = (decoded['id'] ?? '').toString();
      if (id.isNotEmpty) return id;
    }
    throw Exception('Session upload succeeded but response id is missing.');
  }

  // -----------------------------
  // List sessions (Notebook / Unit)
  // -----------------------------
  Future<List<Session>> fetchSessions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/sessions'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load sessions (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw Exception('Invalid sessions response');
    }

    return decoded
        .map<Session>(
          (e) => Session.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  // -----------------------------
  // Fetch single session (Detail)
  // -----------------------------
  Future<Session> fetchSessionById(String sessionId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/sessions/$sessionId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load session');
    }

    final decoded = jsonDecode(response.body);
    return Session.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  // -----------------------------
  // Reprocess session
  // -----------------------------
  Future<void> reprocessSession(String sessionId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/sessions/$sessionId/reprocess'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to reprocess session');
    }
  }

  // -----------------------------
  // Syntra chat (AI assistant)
  // -----------------------------
  Future<String> syntraChat({
    required String message,
    List<String> sessionIds = const [],
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/syntra/chat'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message': message,
        'sessionIds': sessionIds,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Syntra chat failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    return (decoded['reply'] ?? '').toString();
  }

  Stream<String> syntraChatStream({
    required String message,
    List<String> sessionIds = const [],
  }) async* {
    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/api/syntra/chat'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'message': message,
        'sessionIds': sessionIds,
        'stream': true,
      });

      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Syntra chat failed (${response.statusCode})');
      }

      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (!line.startsWith('data:')) continue;
        var data = line.substring(5);
        if (data.startsWith(' ')) data = data.substring(1);
        if (data == '[DONE]') break;
        if (data.isNotEmpty) yield data;
      }
    } finally {
      client.close();
    }
  }

  // -----------------------------
  // Outline extraction (AI)
  // -----------------------------
  Future<Map<String, dynamic>> extractOutline({
    required String filename,
    required Uint8List bytes,
    required String extension,
  }) async {
    final uri = Uri.parse('$baseUrl${ApiConfig.outlineExtractPath}');
    final request = http.MultipartRequest('POST', uri);

    final contentType = _outlineContentType(extension);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: contentType,
      ),
    );

    if (ApiConfig.outlineApiKey.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${ApiConfig.outlineApiKey}';
    }

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Outline extraction failed (${response.statusCode}): $body',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid outline extraction response');
    }
    return decoded;
  }

  MediaType _outlineContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'docx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      default:
        return MediaType('application', 'octet-stream');
    }
  }
}
