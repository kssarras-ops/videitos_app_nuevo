import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/video.dart';

class ApiService {
  static const String baseUrl = 'http://190.107.177.199:8080/api/v1';

  // Para móvil: subir desde archivo
  static Future<Video> uploadVideo(File videoFile, {String? title}) async {
    final uri = Uri.parse('$baseUrl/upload');
    final request = http.MultipartRequest('POST', uri);

    final multipartFile = await http.MultipartFile.fromPath(
      'file',
      videoFile.path,
      contentType: MediaType('video', 'mp4'),
    );
    request.files.add(multipartFile);

    if (title != null) {
      request.fields['title'] = title;
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      return Video.fromJson(data);
    } else {
      throw Exception(
          'Error al subir video: ${response.statusCode} - $responseBody');
    }
  }

  // Para web: subir desde bytes
  static Future<Video> uploadVideoBytes(
    String filename,
    Future<Uint8List> bytesFuture, {
    String? title,
    String mimeType = 'video/mp4',
  }) async {
    final uri = Uri.parse('$baseUrl/upload');
    final request = http.MultipartRequest('POST', uri);

    final bytes = await bytesFuture;
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType.parse(mimeType),
    );
    request.files.add(multipartFile);

    if (title != null) {
      request.fields['title'] = title;
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      return Video.fromJson(data);
    } else {
      throw Exception(
          'Error al subir video: ${response.statusCode} - $responseBody');
    }
  }

  static Future<List<Video>> fetchVideos(
      {int page = 1, int perPage = 20}) async {
    final uri = Uri.parse('$baseUrl/videos').replace(queryParameters: {
      'page': page.toString(),
      'per_page': perPage.toString(),
    });
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> videosJson = data['videos'] ?? [];
      return videosJson.map((json) => Video.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener videos: ${response.statusCode}');
    }
  }

  static Future<void> reportVideo(String videoId, String reason,
      {String reportedBy = 'anonymous'}) async {
    final uri = Uri.parse('$baseUrl/report/$videoId');
    final request = http.MultipartRequest('POST', uri);
    request.fields['razón'] = reason;
    request.fields['reported_by'] = reportedBy;

    final response = await request.send();
    if (response.statusCode != 200) {
      final responseBody = await response.stream.bytesToString();
      throw Exception(
          'Error al reportar: ${response.statusCode} - $responseBody');
    }
  }
}
