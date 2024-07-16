import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:tang_network/util/tang_network_util.dart';
import 'package:tang_network/config/tang_network_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:encrypt/encrypt.dart' as ec;

/// Proxy usage.
/// if (kDebugMode) {
///   (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
///     const proxy = '192.168.199.66:9090';
///     final client = HttpClient();
///     client.findProxy = (url) { return 'PROXY $proxy'; };
///     client.badCertificateCallback =
///     (X509Certificate cert, String host, int port) => Platform.isAndroid;
///     return client;
///   };
/// }

//TODO: 拆分Query请求描述、拦截器外置abstract扩展

enum NetworkMethodType {
  post, get
}

enum FileUploadingType {
  formData, multipleFileData
}

const _kURLExtraParamNeedsAutoSetupDeviceInfo = 'needsAutoSetupDeviceInfo';
const _kURLExtraParamValue = '1';

class NetworkHttp {

  factory NetworkHttp() => _getInstance();
  static NetworkHttp _getInstance() { return _instance; }
  static NetworkHttp get shared => _getInstance();
  static final NetworkHttp _instance = NetworkHttp._internal();
  NetworkHttp._internal() {
    /// init...
  }

  final Dio _dio = Dio();
  late NetworkHttpConfig _config;
  String? _version, _buildNo, _deviceId, _deviceModel, _deviceBrand,
      _deviceDisplay, _deviceHardware;
  
  /// Json.
  final jsonEncoder = const JsonEncoder();

  /// Encrypt.
  final encryptor = ec.Encrypter(ec.AES(
    ec.Key.fromUtf8('Consts.kAesKey'),
    mode: ec.AESMode.cbc,
  ));
  final ec.IV iv = ec.IV.fromUtf8('Consts.kAesIv');

  /// Cache.
  /// key : the encrypted 'data of response map'.
  final Map<String, String> memoryCache = {};

  /// Setup.
  setup({required NetworkHttpConfig config}) async {
    _config = config;
    _config.callbacks?.handleOnDioSetup(_dio, true);

    /// Basic.
    _dio.options.connectTimeout = Duration(
      milliseconds: config.base.connectionTimeoutMs,
    );
    _dio.options.receiveTimeout = Duration(
      milliseconds: config.base.receiveTimeoutMs,
    );

    /// Headers.
    _dio.interceptors
      ..add(PrettyDioLogger(
        requestHeader: !kReleaseMode,
        requestBody: !kReleaseMode,
        responseBody: !kReleaseMode,
        responseHeader: !kReleaseMode,
        compact: true,
      ))
      ..add(InterceptorsWrapper(onRequest: (options, handler) async {
        await _setupDeviceInfoIfNeeded(options.headers);
        options.headers['DID'] = _deviceId;
        options.headers['DSOURCE'] = (Platform.isIOS ? 'ios':'android');
        options.headers['DMODEL'] = _deviceModel;
        options.headers['DBRAND'] = _deviceBrand;
        options.headers['DDISPLAY'] = _deviceDisplay;
        options.headers['DHARDWARE'] = _deviceHardware;
        options.headers['LANG'] = 'zh';
        options.headers['APP-VERSION'] = _version;
        options.headers['APP-BUILD'] = _buildNo;
        options.headers['version'] = _version;
        handler.next(options);
      }, onResponse: (response, handler) {
        handler.next(response);
      }, onError: (exception, handler) {
        handler.next(exception);
      }));

    /// Configuration callback.
    _config.callbacks?.handleOnDioSetup(_dio, false);
  }

  /// Initializing.
  initDeviceInfo() {
    final Map<String, dynamic> param = {
      _kURLExtraParamNeedsAutoSetupDeviceInfo: _kURLExtraParamValue,
    };
    _setupDeviceInfoIfNeeded(param);
  }

  /// Device info setup.
  _setupDeviceInfoIfNeeded(Map<String, dynamic> headers) async {
    if (_deviceModel != null && _deviceId != null && _version != null) return;
    if (headers[_kURLExtraParamNeedsAutoSetupDeviceInfo] != _kURLExtraParamValue) return;
    final platform = await PackageInfo.fromPlatform();
    final dip = DeviceInfoPlugin();
    final dm = Platform.isIOS
        ? (await dip.iosInfo).utsname.machine
        : (await dip.androidInfo).model;
    final brand = Platform.isIOS ? 'Apple' : (await dip.androidInfo).brand;
    final display = Platform.isIOS ? 'Apple' : (await dip.androidInfo).display;
    final hardware = Platform.isIOS ? 'Apple' : (await dip.androidInfo).hardware;
    _version = platform.version;
    _buildNo = platform.buildNumber;
    _deviceId ??= await FlutterUdid.udid;
    _deviceModel = dm;
    _deviceBrand = brand;
    _deviceDisplay = display;
    _deviceHardware = hardware;
  }
}

// Getter

extension GettersEx on NetworkHttp {
  Dio get dio => _dio;
  NetworkHttpConfig get config => _config;
  String get version => _version ?? '';
  String get buildNo => _buildNo ?? '';
  String get deviceId => _deviceId ?? '';
  String get deviceModel => _deviceModel ?? 'Simulator';
  String get deviceBrand => _deviceBrand ?? '';
  String get deviceDisplay => _deviceDisplay ?? '';
  String get deviceHardware => _deviceHardware ?? '';
}

// POST / GET

extension CommonEx on NetworkHttp {

  /// POST/Get请求.
  ///
  /// - [url] .
  /// - [params] The MapObj of HTTP Body.
  /// - [method] `NetworkMethodType`
  /// - [isSimpleResponse] The 'data' could be null or SimpleType
  /// at the response value.
  Future<Map<String, dynamic>> request(
      String url, Map<String, dynamic> params, {
        required NetworkMethodType method,
        bool absoluteUrl = false,
        bool isSimpleResponse = false,
        bool needsAutoSetupDeviceInfo = true,
        bool isUseMemoryCache = false,
        Map<String, String>? customHeaders,
        String? cacheKey,
        List<String>? ignoreErrorCodes,
      }) async {
    final completer = Completer<Map<String, dynamic>>();

    /// Read from cache.
    if (isUseMemoryCache && null != cacheKey) {
      dynamic cacheData = memoryCache[cacheKey];
      if (cacheData is String) {
        if (cacheData.isNotEmpty) {
          return _parsePostBody(
            data: cacheData,
            completer: completer,
          );
        }
      }
    }

    /// Assemble parameters.
    if (!absoluteUrl) url = _config.apiDomain + url;
    Map<String, dynamic> newParams = {};
    newParams.addAll(params);

    // UserModel userModel = await UserService.shared.currentUser;
    // String token = (null == userModel) ? '':(userModel.token ?? '');
    // String jsonParams = jsonEncoder.convert(newParams);

    // String encryptedParams = encryptor.encrypt(jsonParams, iv: iv).base64;
    // String sig = md5enc(encryptor.encrypt(encryptedParams, iv: iv).base64);

    /// Assemble headers.
    var headers = {
      HttpHeaders.contentTypeHeader: 'application/json;charset=UTF-8',
      // 'AUTH-TOKEN': token,
      // 'SIG': sig, //TODO: util interceptor
      'Authorization': _config.getters?.getUserToken(this) ?? '',
    };
    headers.addAll(customHeaders ?? {});
    if (needsAutoSetupDeviceInfo) {
      headers[_kURLExtraParamNeedsAutoSetupDeviceInfo] = _kURLExtraParamValue;
    }
    final options = Options(headers: headers);

    /// Do request.
    Response<Map<String, dynamic>> response;
    switch (method) {
      case NetworkMethodType.get:
        response = await _dio.get(
          url,
          // data: encryptedParams,
          data: params,
          options: options,
        );
      case NetworkMethodType.post:
        response = await _dio.post(
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
    if (response.data is! Map<String, dynamic>) {
      return Future<Map<String, dynamic>>.value(
        {"error": 'Error data format: ${response.data}'},
      );
    }
    if (isSimpleResponse) {
      _handleErrorResponse(response.data ?? {});
      return Future<Map<String, dynamic>>.value(response.data);
    }

    dynamic data = response.data?[_config.keys.responseData];
    if (data is! String) {
      data = response.data?.toJsonStr() ?? '{}';
    }

    /// Cache if needed.
    if (isUseMemoryCache && null != cacheKey) {
      if (null != memoryCache[cacheKey]) {
        memoryCache.remove(cacheKey);
      }
      memoryCache[cacheKey] = data;
    }

    /// Decrypt and parse the body.
    Map<String, dynamic> plainResponse = await _parsePostBody(
      data: data,
      response: response,
      completer: completer,
    );
    _handleErrorResponse(plainResponse, ignoreErrorCodes: ignoreErrorCodes);
    return plainResponse;
  }

  /// Error handling.
  _handleErrorResponse(Map<String, dynamic> response, {
    List<String>? ignoreErrorCodes,
  }) {
    var code = response[_config.keys.responseCode];
    if (code == null) return;

    bool ignoreError = ignoreErrorCodes?.contains(code) ?? false;
    if (_config.codes.success == code) return;
    if (ignoreError) {
      _config.callbacks?.handleErrorMessage(this, code.toString(), true);
    } else {
      final errMsg = response[_config.keys.responseMsg]?.toString()
          ?? '未知错误，请稍后重试';
      _config.callbacks?.handleErrorMessage(this, errMsg, true);
    }
  }
}

// Upload

extension UploadEx on NetworkHttp {

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
    fileKey = fileKey ?? _config.keys.requestFileKey;
    fileSuffix = fileSuffix ?? _config.keys.requestFileSuffix;
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
    url = _config.apiDomain + url;
    final data = FormData.fromMap(parameters);
    final response = await _dio.post(
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

// Download

extension DownloadEx on NetworkHttp {

  /// File download.
  ///
  /// - [url] .
  /// - [savePath] The path to save the downloaded file.
  Future<File> download(String url, String savePath) async {
    final completer = Completer<File>();
    url = _config.apiDomain + url;
    _dio.download(
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

// Parse response

extension _ParseEx on NetworkHttp {

  /// Response parsing.
  ///
  /// - [data] Raw response.
  /// - [completer] Callback.
  /// - [response] The original resposne object.
  Future<Map<String, dynamic>> _parsePostBody({
    required String data,
    required Completer<Map<String, dynamic>> completer,
    Response<Map<String, dynamic>>? response,
  }) {
    // String decryptResponseJson = encryptor.decrypt64(data, iv: iv);
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

    dynamic respCode = responseDataObj[_config.keys.responseCode];
    if (respCode is String) {
      if (respCode == _config.codes.tokenExpired) {
        _config.callbacks?.handleTokenExpiredAction(this, responseDataObj);
      } else if (respCode == _config.codes.lowVersion) {
        _config.callbacks?.handleUpdatesAction(this, responseDataObj);
      }
    }

    completer.complete(Future<Map<String, dynamic>>.value(
        responseDataObj as FutureOr<Map<String, dynamic>>?)
    );
    return completer.future;
  }
}
