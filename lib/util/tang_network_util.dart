import 'dart:convert';

extension TangNetworkHttpMapEx on Map {
  String toJsonStr() => (const JsonEncoder()).convert(this);
}