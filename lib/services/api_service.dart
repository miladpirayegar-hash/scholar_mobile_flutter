import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  static String get _baseUrl => ApiConfig.baseUrl;

  static Future<int> fetchSessionCount() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/sessions'));

    if (response.statusCode != 200) {
      throw Exception('Failed to load sessions');
    }

    final List<dynamic> sessions = jsonDecode(response.body);
    return sessions.length;
  }
}
