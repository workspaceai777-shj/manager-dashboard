import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class StaffApi {
  final String base = AppConfig.apiBase;
  Future<dynamic> request(String action, {Map<String, dynamic>? body}) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('Please sign in');
    if (base.isEmpty) throw Exception('API_BASE_URL is not configured');
    final response = await http.post(
      Uri.parse('${base.replaceAll(RegExp(r"/$"), "")}/api/v2'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'action': action, ...?body}),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(decoded['error'] ?? 'Request failed');
    }
    return decoded;
  }
}
