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
  late String responseCode;
  late String responseMsg;
  late String responseData;
  late String requestFileKey;
  late String requestFileSuffix;
}

/// Response codes;
abstract class NetworkHttpCodes {
  late int success;
  late String tokenExpired;
  late String lowVersion;
}

/// Getter.
abstract class NetworkHttpGetters {
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