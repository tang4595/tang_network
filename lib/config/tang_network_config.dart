import 'package:dio/dio.dart';
import 'package:tang_network/http/tang_network_http.dart';

/// Configuration.
abstract class NetworkHttpConfig {
  /// Basic.
  late String apiDomain;
  late NetworkHttpBase base;
  late NetworkHttpKeys keys;
  late NetworkHttpCodes codes;

  /// Interaction.
  NetworkHttpGetters? getters;
  NetworkHttpCallbacks? callbacks;
}

/// Base.
abstract class NetworkHttpBase {
  late int connectionTimeoutMs;
  late int receiveTimeoutMs;
  late String? aesKey;
  late String? aesIv;
}

/// Response json keys.
abstract class NetworkHttpKeys {
  /// Request.
  late String requestHeaderSource;
  late String requestHeaderDeviceId;
  late String requestHeaderDeviceModel;
  late String requestHeaderDeviceBrand;
  late String requestHeaderDeviceDisplay;
  late String requestHeaderDeviceHardware;
  late String requestHeaderLanguage;
  late String requestHeaderBuildNo;
  late String requestHeaderVersionName;
  late String requestFileKey;
  late String requestFileSuffix;
  /// Response.
  late String responseCode;
  late String responseMsg;
  late String responseData;
}

/// Response codes;
abstract class NetworkHttpCodes {
  late int success;
  late String tokenExpired;
  late String lowVersion;
}

/// Getter.
abstract class NetworkHttpGetters {
  /// Basic.
  String? getDeviceId(NetworkHttp networkHttp);
  String? getDeviceModel(NetworkHttp networkHttp);
  String? getDeviceBrand(NetworkHttp networkHttp);
  String? getDeviceDisplay(NetworkHttp networkHttp);
  String? getDeviceHardware(NetworkHttp networkHttp);
  String? getLanguage(NetworkHttp networkHttp);
  String? getBuildNo(NetworkHttp networkHttp);
  String? getVersionName(NetworkHttp networkHttp);
  /// User token.
  String? getUserToken(NetworkHttp networkHttp);
}

/// Callback.
abstract class NetworkHttpCallbacks {
  onDioSetup(Dio dio, bool beforeBasicInit);
  handleInfoMessage(NetworkHttp networkHttp, String message);
  handleErrorMessage(NetworkHttp networkHttp, String message, bool isIgnored);
  handleTokenExpiredAction(NetworkHttp networkHttp, dynamic context);
  handleUpdatesAction(NetworkHttp networkHttp, dynamic context);
}