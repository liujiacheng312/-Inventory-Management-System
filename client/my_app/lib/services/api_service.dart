import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api.dart';
import '../models/managed_user.dart';

class ApiService {
  static String? _token;

  static void setToken(String token) {
    _token = token;
  }

  static String? get token => _token;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/user/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      _token = data['data']['token'];
      return data['data'];
    }
    throw Exception(data['message'] ?? '登录失败');
  }

  static Future<Map<String, dynamic>> register(
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/user/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      _token = data['data']['token'];
      return data['data'];
    }
    throw Exception(data['message'] ?? '注册失败');
  }

  static Future<List<dynamic>> getMaterials() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/material'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? '获取库存失败');
  }

  static Future<bool> addMaterial(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/material/add'),
      headers: _headers,
      body: jsonEncode(data),
    );

    final result = jsonDecode(response.body);
    return result['success'] == true;
  }

  static Future<bool> updateMaterial(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/material/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );

    final result = jsonDecode(response.body);
    return result['success'] == true;
  }

  static Future<bool> deleteMaterial(int id) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/material/$id'),
      headers: _headers,
    );

    final result = jsonDecode(response.body);
    return result['success'] == true;
  }

  static Future<Map<String, dynamic>> takeMaterial(
    int materialId,
    int count,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/material/take'),
      headers: _headers,
      body: jsonEncode({'material_id': materialId, 'count': count}),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> returnMaterial(
    int materialId,
    int count,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/material/return'),
      headers: _headers,
      body: jsonEncode({'material_id': materialId, 'count': count}),
    );

    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getRecords() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/record'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? '获取记录失败');
  }

  static Future<List<dynamic>> getPendingRecords() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/record/pending'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? '获取待审批记录失败');
  }

  static Future<bool> approveRecord(int id) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/record/approve/$id'),
      headers: _headers,
    );

    final result = jsonDecode(response.body);
    return result['success'] == true;
  }

  static Future<bool> rejectRecord(int id) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/record/reject/$id'),
      headers: _headers,
    );

    final result = jsonDecode(response.body);
    return result['success'] == true;
  }

  static Future<List<ManagedUser>> getUsers() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/user/list'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      return (data['data'] as List<dynamic>)
          .map((item) => ManagedUser.fromJson(item))
          .toList();
    }

    throw Exception(data['message'] ?? '获取用户列表失败');
  }

  static Future<Map<String, dynamic>> updateUserRole(
    int userId,
    String role,
  ) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/user/$userId/role'),
      headers: _headers,
      body: jsonEncode({'role': role}),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> importExcel({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/excel/import'),
    );

    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    return jsonDecode(responseData);
  }

  static String getExportUrl() {
    return '${ApiConfig.baseUrl}/excel/export?token=$_token';
  }
}
