/// Configuration.
abstract class NetworkHttpConfig {
  late String apiDomain;
  late NetworkHttpBase base;
  late NetworkHttpKeys keys;
  late NetworkHttpCodes codes;
}

/// Base.
abstract class NetworkHttpBase {
  late int connectionTimeoutMs;
  late int receiveTimeoutMs;
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