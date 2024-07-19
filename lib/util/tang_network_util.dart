import 'dart:convert';

extension NetworkHttpMapEx on Map {
  String toJsonStr() => (const JsonEncoder()).convert(this);
}