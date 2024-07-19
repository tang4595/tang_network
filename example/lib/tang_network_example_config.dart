import 'package:tang_network/config/tang_network_config.dart';
import 'package:tang_network/http/tang_network_http.dart';
import 'package:dio/dio.dart';

/// Configuration.
class ExampleConfigNetworkHttp implements NetworkHttpConfig {
  @override
  String apiDomain = 'https://sandbox.itunes.apple.com';

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
  late String requestHeaderSource = 'DSOURCE';

  @override
  late String requestHeaderDeviceId = 'DID';

  @override
  late String requestHeaderDeviceModel = 'DMODEL';

  @override
  late String requestHeaderDeviceBrand = 'DBRAND';

  @override
  late String requestHeaderDeviceDisplay = 'DDISPLAY';

  @override
  late String requestHeaderDeviceHardware = 'DHARDWARE';

  @override
  late String requestHeaderLanguage = 'LANG';

  @override
  late String requestHeaderBuildNo = 'BUILD';

  @override
  late String requestHeaderVersionName = 'version';

  @override
  String requestFileKey = 'file';

  @override
  String requestFileSuffix = 'png';

  @override
  String responseData = 'data';

  @override
  String responseMsg = 'message';

  @override
  String responseCode = 'code';
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
  String? getDeviceId(NetworkHttp networkHttp) {
    return null;
  }

  @override
  String? getDeviceModel(NetworkHttp networkHttp) {
    return null;
  }

  @override
  String? getDeviceBrand(NetworkHttp networkHttp) {
    return null;
  }

  @override
  String? getDeviceDisplay(NetworkHttp networkHttp) {
    return null;
  }

  @override
  String? getDeviceHardware(NetworkHttp networkHttp) {
    return null;
  }

  @override
  String? getLanguage(NetworkHttp networkHttp) {
    return null;
  }

  @override
  String? getBuildNo(NetworkHttp networkHttp) {
    return null;
  }

  @override
  String? getVersionName(NetworkHttp networkHttp) {
    return null;
  }


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