import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:tang_network/http/tang_network_http.dart';

class NetworkHttpDownloader {
  final NetworkHttp http;
  NetworkHttpDownloader({required this.http});
}

extension DownloaderEx on NetworkHttpDownloader {

  /// File download.
  ///
  /// - [url] .
  /// - [savePath] The path to save the downloaded file.
  Future<File> download(String url, String savePath) async {
    final completer = Completer<File>();
    url = http.config.apiDomain + url;
    http.dio.download(
      url,
      savePath,
      options: Options(responseType: ResponseType.stream),
    ).then((response) {
      if (response.statusCode != 200) {
        completer.completeError('Failed to download');
        return;
      }
      completer.complete(Future<File>.value(File(savePath)));
    }).catchError((error) {
      completer.completeError(error.toString());
    });
    return completer.future;
  }
}