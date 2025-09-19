import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/media.dart';

class MediaService {
  final String url = "${ApiConfig.baseUrl}/media";

  Future<List<Media>> getAllMedia() async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Media.fromJson(e)).toList();
    }
    throw Exception("Failed to fetch media");
  }

  Future<Media> createMedia(Media media) async {
    final response = await http.post(
      Uri.parse(url),
      headers: ApiConfig.headers,
      body: jsonEncode(media.toJson()),
    );
    if (response.statusCode == 201) {
      return Media.fromJson(jsonDecode(response.body));
    }
    throw Exception("Failed to create media");
  }

  Future<void> updateMedia(Media media) async {
    final response = await http.put(
      Uri.parse("$url/${media.id}"),
      headers: ApiConfig.headers,
      body: jsonEncode(media.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to update media");
    }
  }

  Future<void> deleteMedia(String id) async {
    final response = await http.delete(Uri.parse("$url/$id"));
    if (response.statusCode != 204) {
      throw Exception("Failed to delete media");
    }
  }
}