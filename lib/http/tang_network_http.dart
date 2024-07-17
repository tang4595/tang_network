import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:tang_network/http/tang_network_http_download.dart';
import 'package:tang_network/http/tang_network_http_parse.dart';
import 'package:tang_network/http/tang_network_http_request.dart';
import 'package:tang_network/http/tang_network_http_upload.dart';
import 'package:tang_network/config/tang_network_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

enum NetworkMethodType {
  post, get
}

enum FileUploadingType {
  formData, multipleFileData
}

const kURLExtraParamNeedsAutoSetupDeviceInfo = 'needsAutoSetupDeviceInfo';
const kURLExtraParamValue = '1';
const _kDefaultAesKey = 'l[-a?.^aQvr_Ak-.';
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
  String? _version, _buildNo, _deviceId, _deviceModel, _deviceBrand,
      _deviceDisplay, _deviceHardware;

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
  Dio get dio => _dio;
  NetworkHttpConfig get config => _config;
  ec.Encrypter? get aesEncryptor => _encryptor;
  ec.IV? get aesIv => _iv;
  NetworkHttpParser get parser => _parser;
  Map<String, String> get memoryCache => _memoryCache;
  /// Keys.
  String get version => _version ?? '';
  String get buildNo => _buildNo ?? '';
  String get deviceId => _deviceId ?? '';
  String get deviceModel => _deviceModel ?? 'Simulator';
  String get deviceBrand => _deviceBrand ?? '';
  String get deviceDisplay => _deviceDisplay ?? '';
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

// Request

extension RequestEx on NetworkHttp {

  /// POST/Get请求.
  ///
  /// - [url] .
  /// - [params] The MapObj of HTTP Body.
  /// - [method] `NetworkMethodType`
  /// - [isSimpleResponse] The 'data' could be null or SimpleType
  /// at the response value.
  /// - [ignoreErrorCodes] The response codes that will not be recognize.
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
    return _request.request(
      url,
      params,
      method: method,
      absoluteUrl: absoluteUrl,
      isSimpleResponse: isSimpleResponse,
      needsAutoSetupDeviceInfo: needsAutoSetupDeviceInfo,
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