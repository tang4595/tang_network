import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:tang_network/http/tang_network_http.dart';
import 'package:tang_network/http/tang_network_http_parse.dart';

class NetworkHttpRequest {
  final NetworkHttp http;
  NetworkHttpRequest({required this.http});
}

extension RequestsEx on NetworkHttpRequest {

  /// Http request.
  ///
  /// - [url] .
  /// - [params] The MapObj of HTTP Body.
  /// - [method] `NetworkMethodType`.
  /// - [isRawResponse] Returning the response raw data directly.
  /// - [isSimpleResponse] The 'data' could be null or SimpleType
  /// at the response value.
  /// - [isNeedAutoSetupDeviceInfo] Automatic invoking
  /// the `_setupDeviceInfoIfNeeded`.
  /// - [ignoreErrorCodes] The response codes that will not be recognize.
  Future<Map<String, dynamic>> request(
      String url, Map<String, dynamic> params, {
        required NetworkMethodType method,
        bool absoluteUrl = false,
        bool isRawResponse = false,
        bool isSimpleResponse = false,
        bool isNeedAutoSetupDeviceInfo = true,
        bool isUseMemoryCache = false,
        String? cacheKey,
        Map<String, String>? customHeaders,
        List<String>? ignoreErrorCodes,
      }) async {
    final completer = Completer<Map<String, dynamic>>();

    /// Read from cache.
    if (isUseMemoryCache && null != cacheKey) {
      dynamic cacheData = http.memoryCache[cacheKey];
      if (cacheData is String) {
        if (cacheData.isNotEmpty) {
          return http.parser.parseResponseBody(
            data: cacheData,
            completer: completer,
          );
        }
      }
    }

    /// Assemble parameters.
    if (!absoluteUrl) url = http.config.apiDomain + url;
    Map<String, dynamic> newParams = {};
    newParams.addAll(params);

    /// Assemble headers.
    var headers = {
      HttpHeaders.contentTypeHeader: 'application/json;charset=UTF-8',
    };
    headers.addAll(customHeaders ?? {});
    if (isNeedAutoSetupDeviceInfo) {
      headers[kURLExtraParamNeedsAutoSetupDeviceInfo] = kURLExtraParamValue;
    }
    final options = Options(headers: headers);

    /// Do request.
    Response<dynamic> response;
    switch (method) {
      case NetworkMethodType.get:
        response = await http.dio.get(
          url,
          // data: encryptedParams,
          data: params,
          options: options,
        );
      case NetworkMethodType.post:
        response = await http.dio.post(
          url,
          // data: encryptedParams,
          data: params,
          options: options,
        );
    }

    /// Response validation.
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
    if (isRawResponse) {
      return Future<Map<String, dynamic>>.value(
        {"value": '${response.data}'},
      );
    }
    if (response.data is! Map<String, dynamic>) {
      return Future<Map<String, dynamic>>.value(
        {"error": 'Error data format: ${response.data}'},
      );
    }
    if (isSimpleResponse) {
      _processingResponseError(response.data ?? {});
      return Future<Map<String, dynamic>>.value(response.data);
    }

    dynamic data = response.data?[http.config.keys.responseData];
    if (data is! String) {
      data = response.data?.toJsonStr() ?? '{}';
    }

    /// Cache if needed.
    if (isUseMemoryCache && null != cacheKey) {
      if (null != http.memoryCache[cacheKey]) {
        http.memoryCache.remove(cacheKey);
      }
      http.memoryCache[cacheKey] = data;
    }

    /// Decrypt and parse the body.
    Map<String, dynamic> plainResponse = await http.parser.parseResponseBody(
      data: data,
      response: response,
      completer: completer,
    );
    _processingResponseError(plainResponse, ignoreErrorCodes: ignoreErrorCodes);
    return plainResponse;
  }
}

extension ErrorEx on NetworkHttpRequest {
  
  /// Error handling.
  _processingResponseError(Map<String, dynamic> response, {
    List<String>? ignoreErrorCodes,
  }) {
    var code = response[http.config.keys.responseCode];
    if (code == null) return;

    bool ignoreError = ignoreErrorCodes?.contains(code) ?? false;
    if (http.config.codes.success == code) return;
    if (ignoreError) {
      http.config.callbacks?.handleErrorMessage(http, code.toString(), true);
    } else {
      final errMsg = response[http.config.keys.responseMsg]?.toString()
          ?? '未知错误，请稍后重试';
      http.config.callbacks?.handleErrorMessage(http, errMsg, true);
    }
  }
}