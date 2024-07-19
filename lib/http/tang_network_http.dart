import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:tang_network/http/tang_network_http_download.dart';
import 'package:tang_network/http/tang_network_http_parse.dart';
import 'package:tang_network/http/tang_network_http_request.dart';
import 'package:tang_network/http/tang_network_http_upload.dart';
import 'package:tang_network/config/tang_network_config.dart';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as ec;

/// * Proxy usage sample.
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
///
/// * Request signature sample.
/// String jsonParams = _jsonEncoder.convert(newParams);
/// String encryptedParams = _encryptor.encrypt(jsonParams, iv: _iv).base64;
/// String sig = md5enc(_encryptor.encrypt(encryptedParams, iv: _iv).base64);

/// Request method.
enum NetworkMethodType {
  post, get
}

/// Upload mode.
enum FileUploadingType {
  formData, multipleFileData
}

/// Internal - key.
const kURLExtraParamNeedsAutoSetupDeviceInfo = 'needsAutoSetupDeviceInfo';
/// Internal - key.
const kURLExtraParamValue = '1';
/// Internal - AES.
const _kDefaultAesKey = 'l[-a?.^aQvr_Ak-.';
/// Internal - AES.
const _kDefaultAesIv = '_a1]/-r`q-.|ghbn';

class NetworkHttp {

  factory NetworkHttp() => _getInstance();
  static NetworkHttp _getInstance() { return _instance; }
  static NetworkHttp get shared => _getInstance();
  static final NetworkHttp _instance = NetworkHttp._internal();
  NetworkHttp._internal() {
    /// init...
  }

  /// DIO instance.
  final Dio _dio = Dio();

  /// Configuration instance.
  late NetworkHttpConfig _config;
  
  /// Json Encoder.
  ///final _jsonEncoder = const JsonEncoder(); import 'dart:convert';

  /// Encrypt.
  ec.Encrypter? _encryptor;
  ec.IV? _iv;

  /// Package info.
  String? _version, _buildNo, _language,
      _deviceId, _deviceModel, _deviceBrand, _deviceDisplay, _deviceHardware;

  /// Cache.
  /// key : the encrypted 'data of response map'.
  final Map<String, String> _memoryCache = {};

  /// Component - Parser.
  late NetworkHttpParser _parser;

  /// Component - Parser.
  late NetworkHttpDownloader _downloader;

  /// Component - Parser.
  late NetworkHttpUploader _uploader;

  /// Component - Parser.
  late NetworkHttpRequest _request;
}

// Getter

extension GettersEx on NetworkHttp {
  /// Utils.
  ///
  /// Dio instance.
  Dio get dio => _dio;
  /// Configuration instance.
  NetworkHttpConfig get config => _config;
  /// EC instance.
  ec.Encrypter? get aesEncryptor => _encryptor;
  /// EC instance.
  ec.IV? get aesIv => _iv;
  /// Http response parser instance.
  NetworkHttpParser get parser => _parser;
  /// The memory caches container.
  Map<String, String> get memoryCache => _memoryCache;

  /// Base info.
  ///
  /// Version name.
  String get version => _version ?? '';
  /// Build number.
  String get buildNo => _buildNo ?? '';
  /// Language code.
  String get language => _language ?? '';
  /// Device unique ID.
  String get deviceId => _deviceId ?? '';
  /// Device model name.
  String get deviceModel => _deviceModel ?? '';
  /// Device brand, android only.
  String get deviceBrand => _deviceBrand ?? '';
  /// Device displaying name, android only.
  String get deviceDisplay => _deviceDisplay ?? '';
  /// Device hardware name, android only.
  String get deviceHardware => _deviceHardware ?? '';
}

// Setup

extension SetupEx on NetworkHttp {

  /// Setup.
  ///
  /// - [config] NetworkHttpConfig.
  setup({required NetworkHttpConfig config}) async {
    _config = config;
    _config.callbacks?.onDioSetup(_dio, true);

    /// Encryptor.
    _encryptor = ec.Encrypter(ec.AES(
      ec.Key.fromUtf8(_config.base.aesKey ?? _kDefaultAesKey),
      mode: ec.AESMode.cbc,
    ));
    _iv = ec.IV.fromUtf8(_config.base.aesIv ?? _kDefaultAesIv);

    /// Internal components.
    _parser = NetworkHttpParser(http: this);
    _downloader = NetworkHttpDownloader(http: this);
    _uploader = NetworkHttpUploader(http: this);
    _request = NetworkHttpRequest(http: this);

    /// Timeout.
    _dio.options.connectTimeout = Duration(
      milliseconds: config.base.connectionTimeoutMs,
    );
    _dio.options.receiveTimeout = Duration(
      milliseconds: config.base.receiveTimeoutMs,
    );

    /// Common headers.
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
        final token = _config.getters?.getUserToken(this) ?? '';
        options.headers[HttpHeaders.authorizationHeader] = token;
        options.headers[_config.keys.requestHeaderSource] = Platform.operatingSystem;
        options.headers[_config.keys.requestHeaderDeviceId] = _deviceId;
        options.headers[_config.keys.requestHeaderDeviceModel] = _deviceModel;
        options.headers[_config.keys.requestHeaderDeviceBrand] = _deviceBrand;
        options.headers[_config.keys.requestHeaderDeviceDisplay] = _deviceDisplay;
        options.headers[_config.keys.requestHeaderDeviceHardware] = _deviceHardware;
        options.headers[_config.keys.requestHeaderLanguage] = _language;
        options.headers[_config.keys.requestHeaderBuildNo] = _buildNo;
        options.headers[_config.keys.requestHeaderVersionName] = _version;
        handler.next(options);
      }, onResponse: (response, handler) {
        handler.next(response);
      }, onError: (exception, handler) {
        handler.next(exception);
      }));

    /// Configuration callback.
    _config.callbacks?.onDioSetup(_dio, false);
  }

  /// Initializing.
  setupDeviceInfo() async {
    final Map<String, dynamic> param = {
      kURLExtraParamNeedsAutoSetupDeviceInfo: kURLExtraParamValue,
    };
    await _setupDeviceInfoIfNeeded(param);
  }

  /// Device info setup.
  _setupDeviceInfoIfNeeded(Map<String, dynamic> headers) async {
    if (_deviceModel != null && _deviceId != null && _version != null) return;
    if (headers[kURLExtraParamNeedsAutoSetupDeviceInfo] != kURLExtraParamValue) return;
    _version = await _config.getters?.getVersionName(this) ?? '';
    _buildNo = await _config.getters?.getBuildNo(this) ?? '';
    _language = await _config.getters?.getLanguage(this) ?? '';
    _deviceId = await _config.getters?.getDeviceId(this) ?? '';
    _deviceModel = await _config.getters?.getDeviceModel(this) ?? '';
    _deviceBrand = await _config.getters?.getDeviceBrand(this) ?? '';
    _deviceDisplay = await _config.getters?.getDeviceDisplay(this) ?? '';
    _deviceHardware = await _config.getters?.getDeviceHardware(this) ?? '';
  }
}

// Request

extension RequestEx on NetworkHttp {

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
    return _request.request(
      url,
      params,
      method: method,
      absoluteUrl: absoluteUrl,
      isRawResponse: isRawResponse,
      isSimpleResponse: isSimpleResponse,
      isNeedAutoSetupDeviceInfo: isNeedAutoSetupDeviceInfo,
      isUseMemoryCache: isUseMemoryCache,
      customHeaders: customHeaders,
      cacheKey: cacheKey,
      ignoreErrorCodes: ignoreErrorCodes,
    );
  }
}

// Upload

extension UploadEx on NetworkHttp {

  /// File upload.
  Future<Map<String, dynamic>> upload(String url, {
    required FileUploadingType type,
    required List<List<int>> fileBytes,
    String? fileKey,
    String? fileSuffix,
    Map<String, dynamic>? params,
    Function(int count, int total)? onSendProgress,
  }) async {
    return _uploader.upload(
      url,
      type: type,
      fileBytes: fileBytes,
      fileKey: fileKey,
      fileSuffix: fileSuffix,
      params: params,
      onSendProgress: onSendProgress,
    );
  }
}

// Download

extension DownloadEx on NetworkHttp {

  /// File download.
  ///
  /// - [url] .
  /// - [savePath] The path to save the downloaded file.
  Future<File> download(String url, String savePath) async {
    return _downloader.download(url, savePath);
  }
}