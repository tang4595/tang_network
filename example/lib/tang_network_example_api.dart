import 'package:tang_network/tang_network.dart';

class NetworkExampleApi {
  Future<String> getJson(String param1, String param2) {
    return NetworkHttp.shared.request('/verifyReceipt',
      {
        'param1': param1,
        'param2': param2,
      },
      method: NetworkMethodType.get,
      isSimpleResponse: true,
    ).then((value) => value.toString());
  }
}