import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class CosmosService {
  static const String _endpoint =
      'https://farmlinkcosmosdb.documents.azure.com:443';

  static const String _masterKey =
      'EKfgTSLTGpiBhf7GFWWTUzzSsBgLWQ4ykLIPWyl07bwsvR3M9al1cHh6lr11aaj1Lzn1KMfgXdA6ACDbITplpg==';

  static const String _databaseId = 'farmlinkDB';
  static const String _containerId = 'Telemetry';
  static const String _healthContainerId = 'HealthStatus';
  // ================================
  // 🔐 AUTHORIZATION GENERATOR
  // ================================
  static String _generateAuthHeader(
      String verb, String resourceType, String resourceLink, String date) {
    final key = base64Decode(_masterKey);

    final payload =
        '${verb.toLowerCase()}\n${resourceType.toLowerCase()}\n$resourceLink\n${date.toLowerCase()}\n\n';

    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(utf8.encode(payload));
    final signature = base64Encode(digest.bytes);

    return Uri.encodeComponent('type=master&ver=1.0&sig=$signature');
  }

  // ================================
  // 📡 GET LATEST TELEMETRY FOR ANIMAL
  // ================================
  static Future<List<Map<String, dynamic>>> getLatestTelemetry(
      String animalID) async {
    try {
      final verb = 'POST';
      final resourceType = 'docs';
      final resourceLink = 'dbs/$_databaseId/colls/$_containerId';
      final date = HttpDate.format(DateTime.now().toUtc());
      final auth = _generateAuthHeader(verb, resourceType, resourceLink, date);

      final uri = Uri.parse('$_endpoint/$resourceLink/$resourceType');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': auth,
          'x-ms-date': date,
          'x-ms-version': '2018-12-31',
          'Content-Type': 'application/query+json',
          'x-ms-documentdb-isquery': 'true',
          'x-ms-documentdb-query-enablecrosspartition': 'true',
          'x-ms-documentdb-partitionkey': jsonEncode([animalID]),
        },
        body: jsonEncode({
          'query':
              "SELECT TOP 20 * FROM c WHERE c.animalID = @id ORDER BY c._ts DESC",
          'parameters': [
            {'name': '@id', 'value': animalID}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['Documents'] ?? []);
      }

      debugPrint(
          'getLatestTelemetry ERROR: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      debugPrint('getLatestTelemetry EXCEPTION: $e');
      return [];
    }
  }
// ================================
// 🧠 GET LATEST HEALTH STATUS (ML)
// ================================
static Future<Map<String, dynamic>?> getLatestHealthStatus(
    String animalID) async {
  try {
    final verb = 'POST';
    final resourceType = 'docs';
    final resourceLink =
        'dbs/$_databaseId/colls/$_healthContainerId';
    final date = HttpDate.format(DateTime.now().toUtc());
    final auth =
        _generateAuthHeader(verb, resourceType, resourceLink, date);

    final uri = Uri.parse('$_endpoint/$resourceLink/$resourceType');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': auth,
        'x-ms-date': date,
        'x-ms-version': '2018-12-31',
        'Content-Type': 'application/query+json',
        'x-ms-documentdb-isquery': 'true',
        'x-ms-documentdb-query-enablecrosspartition': 'true',
        'x-ms-documentdb-partitionkey': jsonEncode([animalID]),
      },
      body: jsonEncode({
        'query':
            "SELECT TOP 1 * FROM c WHERE c.animalID = @id ORDER BY c._ts DESC",
        'parameters': [
          {'name': '@id', 'value': animalID}
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final docs = data['Documents'] ?? [];
      return docs.isNotEmpty ? docs.first : null;
    }

    debugPrint(
        'getLatestHealthStatus ERROR: ${response.statusCode} - ${response.body}');
    return null;
  } catch (e) {
    debugPrint('getLatestHealthStatus EXCEPTION: $e');
    return null;
  }
}
  static Future<List<Map<String, dynamic>>> getAllSickAnimals() async {
    try {
      const containerId = 'HealthStatus';

      final verb = 'POST';
      final resourceType = 'docs';
      final resourceLink = 'dbs/$_databaseId/colls/$containerId';
      final date = HttpDate.format(DateTime.now().toUtc());

      final auth = _generateAuthHeader(
        verb,
        resourceType,
        resourceLink,
        date,
      );

      final uri = Uri.parse('$_endpoint/$resourceLink/docs');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': auth,
          'x-ms-date': date,
          'x-ms-version': '2018-12-31',
          'Content-Type': 'application/query+json',
          'x-ms-documentdb-isquery': 'true',
          'x-ms-documentdb-query-enablecrosspartition': 'true',
        },
        body: jsonEncode({
          "query": "SELECT * FROM c WHERE c.isSick = true",
          "parameters": []   // ✅ VERY IMPORTANT (fixes 400 error)
        }),
      );

      print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['Documents'] ?? []);
      }

      return [];
    } catch (e) {
      print("EXCEPTION: $e");
      return [];
    }
  }
  // ================================
  // 🐑 GET ALL UNIQUE ANIMALS WITH TELEMETRY
  // ================================
  static Future<List<Map<String, dynamic>>> getAnimals() async {
    try {
      final verb = 'POST';
      final resourceType = 'docs';
      final resourceLink = 'dbs/$_databaseId/colls/$_containerId';
      final date = HttpDate.format(DateTime.now().toUtc());
      final auth = _generateAuthHeader(verb, resourceType, resourceLink, date);

      final uri = Uri.parse('$_endpoint/$resourceLink/$resourceType');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': auth,
          'x-ms-date': date,
          'x-ms-version': '2018-12-31',
          'Content-Type': 'application/query+json',
          'x-ms-documentdb-isquery': 'true',
          'x-ms-documentdb-query-enablecrosspartition': 'true',
        },
        body: jsonEncode({
          'query': 'SELECT * FROM c', // fetch all documents
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final docs = List<Map<String, dynamic>>.from(data['Documents'] ?? []);

        // Remove duplicates by animalID and keep full document
        final Map<String, Map<String, dynamic>> uniqueAnimals = {};
        for (var doc in docs) {
          final id = doc['animalID'] ?? doc['id'];
          uniqueAnimals[id] = doc; // latest overwrites previous if duplicate
        }

        return uniqueAnimals.values.toList();
      }

      debugPrint('getAnimals ERROR: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      debugPrint('getAnimals EXCEPTION: $e');
      return [];
    }
  }
}

