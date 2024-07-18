import 'package:tang_network/config/tang_network_config.dart';
import 'package:tang_network/http/tang_network_http.dart';
import 'package:dio/dio.dart';

/// Configuration.
class ExampleConfigNetworkHttp implements NetworkHttpConfig {
  @override
  String apiDomain = 'https://www.apple.com/';

  @override
  NetworkHttpBase base = ExampleConfigNetworkHttpBase();

  @override
  NetworkHttpKeys keys = ExampleConfigNetworkHttpKeys();

  @override
  NetworkHttpCodes codes = ExampleConfigNetworkHttpCodes();

  @override
  NetworkHttpGetters? getters = ExampleConfigNetworkHttpGetters();

  @override
  NetworkHttpCallbacks? callbacks = ExampleConfigNetworkHttpCallbacks();
}

/// Base.
class ExampleConfigNetworkHttpBase implements NetworkHttpBase {
  @override
  int connectionTimeoutMs = 30000;

  @override
  int receiveTimeoutMs = 60000;

  @override
  String? aesIv;

  @override
  String? aesKey;
}

/// Keys.
class ExampleConfigNetworkHttpKeys implements NetworkHttpKeys {
  @override
  String requestFileKey = 'file';

  @override
  String requestFileSuffix = 'png';

  @override
  String responseCode = 'code';

  @override
  String responseData = 'data';

  @override
  String responseMsg = 'message';
}

/// Codes.
class ExampleConfigNetworkHttpCodes implements NetworkHttpCodes {
  @override
  int success = 200;

  @override
  String lowVersion = '50000';

  @override
  String tokenExpired = '50001';
}

/// Getters.
class ExampleConfigNetworkHttpGetters implements NetworkHttpGetters {
  @override
  String? getUserToken(NetworkHttp networkHttp) {
    return 'SSUserActor.shared.token';
  }
}

/// Callbacks.
class ExampleConfigNetworkHttpCallbacks implements NetworkHttpCallbacks {
  @override
  onDioSetup(Dio dio, bool beforeBasicInit) {

  }

  @override
  handleErrorMessage(NetworkHttp networkHttp, String message, bool isIgnored) {
    if (isIgnored || message.isEmpty) return;
    ///Toast.info(message);
  }

  @override
  handleInfoMessage(NetworkHttp networkHttp, String message) {

  }

  @override
  handleTokenExpiredAction(NetworkHttp networkHttp, context) {
    // UserService.shared.setUser(null);
    ///Navigation.navigationEventBus.fire(TokenExpiredEvent());
  }

  @override
  handleUpdatesAction(NetworkHttp networkHttp, context) {
    //ConfigService.shared.setHasUpdate(true);
  }
}