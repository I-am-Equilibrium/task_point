import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class LocalStorageService {
  /// Генерация уникального ключа под конкретного пользователя
  static String _keyForUser(String userId) => 'groups_full_structure_$userId';

  /// Преобразуем Color → int и рекурсивно сериализуем Map/List
  static dynamic _toEncodable(dynamic value) {
    if (value is Color) return value.value;

    if (value is Map) {
      final Map<String, dynamic> out = {};
      value.forEach((k, v) {
        out[k] = _toEncodable(v);
      });
      return out;
    }

    if (value is List) {
      return value.map(_toEncodable).toList();
    }

    return value; // примитивы
  }

  /// Сохраняем структуру конкретного пользователя
  static Future<void> saveGroupsStructure(
    List<Map<String, dynamic>> structure, {
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final safe = _toEncodable(structure);
    final jsonStr = jsonEncode(safe);

    await prefs.setString(_keyForUser(userId), jsonStr);
  }

  /// Загружаем структуру конкретного пользователя
  static Future<List<Map<String, dynamic>>> loadGroupsStructure({
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyForUser(userId));

    if (jsonStr == null || jsonStr.isEmpty) return [];

    final decoded = jsonDecode(jsonStr) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Очищаем структуру конкретного пользователя
  static Future<void> clearGroupsStructure({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyForUser(userId));
  }

  /// Старый метод — оставляем пустым, чтобы не ломать проект
  static Future<List<String>> getListOrder() async => [];
}
