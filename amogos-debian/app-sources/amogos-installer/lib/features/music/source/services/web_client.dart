// Adapted from the user's AmogOS Music project.
import 'dart:convert';

import 'package:http/http.dart' as http;

class WebClient {
  WebClient({http.Client? client}) : client = client ?? http.Client();
  final http.Client client;
  static const agent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36';

  Future<String> text(Uri uri, {Map<String, String> headers = const {}}) async {
    final response = await client
        .get(uri, headers: {'User-Agent': agent, ...headers})
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw SourceException(
        'The source returned ${response.statusCode}. Please try again.',
        statusCode: response.statusCode,
      );
    }
    return response.body;
  }

  Future<dynamic> getJson(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async => jsonDecode(await text(uri, headers: headers));

  Future<Map<String, dynamic>> postJson(
    Uri uri,
    Map<String, dynamic> body, {
    Map<String, String> headers = const {},
  }) async {
    final response = await client
        .post(
          uri,
          headers: {
            'User-Agent': agent,
            'Content-Type': 'application/json',
            ...headers,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw SourceException(
        'The source returned ${response.statusCode}. Please try again.',
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void close() => client.close();
}

class SourceException implements Exception {
  const SourceException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
