import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:tang_network/http/tang_network_http.dart';

class NetworkHttpParser {
  final NetworkHttp http;
  NetworkHttpParser({required this.http});
}

extension ParseEx on NetworkHttpParser {

  /// Response parsing.
  ///
  /// - [data] Raw response.
  /// - [completer] Callback.
  /// - [response] The original resposne object.
  Future<Map<String, dynamic>> parseResponseBody({
    required String data,
    required Completer<Map<String, dynamic>> completer,
    Response<Map<String, dynamic>>? response,
  }) {
    // String decryptResponseJson = encrypt.decrypt64(data, iv: iv);
    String decryptResponseJson = data;

    if (decryptResponseJson.isEmpty) {
      return Future<Map<String, dynamic>>.value(
        {"error": 'Error decrypt data: ${response?.data}'},
      );
    }

    dynamic responseDataObj = json.decode(decryptResponseJson);
    if (responseDataObj is! Map<String, dynamic>) {
      return Future<Map<String, dynamic>>.value(
        {"error": 'Error parsed response data: ${response?.data}'},
      );
    }

    dynamic respCode = responseDataObj[http.config.keys.responseCode];
    if (respCode is String) {
      if (respCode == http.config.codes.tokenExpired) {
        http.config.callbacks?.handleTokenExpiredAction(http, responseDataObj);
      } else if (respCode == http.config.codes.lowVersion) {
        http.config.callbacks?.handleUpdatesAction(http, responseDataObj);
      }
    }

    completer.complete(Future<Map<String, dynamic>>.value(
        responseDataObj as FutureOr<Map<String, dynamic>>?)
    );
    return completer.future;
  }
}