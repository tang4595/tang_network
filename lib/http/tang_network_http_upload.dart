import 'dart:async';
import 'package:dio/dio.dart';
import 'package:tang_network/http/tang_network_http.dart';

class NetworkHttpUploader {
  final NetworkHttp http;
  NetworkHttpUploader({required this.http});
}

extension UploaderEx on NetworkHttpUploader {

  /// File upload.
  Future<Map<String, dynamic>> upload(String url, {
    required FileUploadingType type,
    required List<List<int>> fileBytes,
    String? fileKey,
    String? fileSuffix,
    Map<String, dynamic>? params,
    Function(int count, int total)? onSendProgress,
  }) async {
    if (fileBytes.isEmpty) {
      return Future.value({'error': 'Error with empty file bytes.'});
    }

    /// Parameter assembling.
    fileKey = fileKey ?? http.config.keys.requestFileKey;
    fileSuffix = fileSuffix ?? http.config.keys.requestFileSuffix;
    Map<String, dynamic> parameters = params ?? {};
    switch (type) {
      case FileUploadingType.formData:
        parameters[fileKey] = MultipartFile.fromBytes(fileBytes.first);
        parameters['name'] = '$fileKey.$fileSuffix';
        break;
      case FileUploadingType.multipleFileData:
        int index = 0;
        parameters[fileKey] = fileBytes.map((e) {
          return MultipartFile.fromBytes(
            e,
            filename: '${fileKey}_$index.$fileSuffix',
          );
        }).toList();
        break;
    }

    /// Do request.
    url = http.config.apiDomain + url;
    final data = FormData.fromMap(parameters);
    final response = await http.dio.post(
      url,
      data: data,
      onSendProgress: onSendProgress,
    );
    if (response.statusCode != 200) {
      return Future<Map<String, dynamic>>.value(
        {"error": 'Error with Http Code: ${response.statusCode}'},
      );
    }
    if (null == response.data) {
      return Future<Map<String, dynamic>>.value(
        {"error": 'Error data: ${response.data}'},
      );
    }
    return response.data;
  }
}