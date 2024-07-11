import 'package:tang_network/http/tang_network_http.dart';

class NetworkRespModel {
  NetworkRespModel({
    num? code,
    String? msg,
    NetworkRespDataConvertable? data,
    List<NetworkRespDataConvertable>? dataList,
  }) {
    _code = code;
    _msg = msg;
    _data = data;
    _dataList = dataList;
  }

  num? _code;
  String? _msg;
  NetworkRespDataConvertable? _data;
  List<NetworkRespDataConvertable>? _dataList;
  num? get code => _code;
  String? get msg => _msg;
  NetworkRespDataConvertable? get data => _data;
  List<NetworkRespDataConvertable>? get dataList => _dataList;

  NetworkRespModel.fromJson(dynamic json) {
    _code = json[NetworkHttp.shared.config.keys.responseCode];
    _msg = json[NetworkHttp.shared.config.keys.responseMsg];
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map[NetworkHttp.shared.config.keys.responseCode] = _code;
    map[NetworkHttp.shared.config.keys.responseMsg] = _msg;

    if (_data != null) {
      map[NetworkHttp.shared.config.keys.responseData] =
          _data?.toJsonObject() ?? {};
    } else if (_dataList != null) {
      map[NetworkHttp.shared.config.keys.responseData] = _dataList?.map((e) =>
          e.toJsonObject()).toList() ?? [];
    }
    return map;
  }

  NetworkRespModel copyWith({
    num? code,
    String? msg,
    NetworkRespDataConvertable? data,
    List<NetworkRespDataConvertable>? dataList,
  }) => NetworkRespModel(
    code: code ?? _code,
    msg: msg ?? _msg,
    data: data ?? _data,
    dataList: dataList ?? _dataList,
  );
}

// Define

abstract class NetworkRespDataConvertable {
  Map<String, dynamic> toJsonObject();
}

// Utils

extension NetworkRespModelUtilsEx on NetworkRespModel {
  bool get isSuccess => _code == NetworkHttp.shared.config.codes.success;

  setCode(num? code) { _code = code; }
  setMsg(String? msg) { _msg = msg; }

  setBaseInfo(num? code, String? msg) {
    _code = code;
    _msg = msg;
  }

  setBase(Map<String, dynamic> json) {
    setBaseInfo(
      json[NetworkHttp.shared.config.keys.responseCode],
      json[NetworkHttp.shared.config.keys.responseMsg],
    );
  }
}