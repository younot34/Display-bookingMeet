import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/device.dart';

class DeviceService {
  final String url = "${ApiConfig.baseUrl}/devices";

  Future<List<Device>> getDevices() async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Device.fromJson(e)).toList();
    }
    throw Exception("Failed to fetch devices");
  }

  Stream<List<Device>> getDevicesStream({Duration interval = const Duration(seconds: 2)}) {
    return Stream.periodic(interval).asyncMap((_) => getDevices());
  }

  Future<String> getLocation(String roomName) async {
    final response = await http.get(Uri.parse("$url?room_name=$roomName"));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        final device = Device.fromJson(data.first);
        return device.location ?? "Unknown";
      }
      return "Unknown";
    }
    throw Exception("Failed to fetch location for $roomName");
  }

  Future<Device> createDevice(Device device) async {
    final response = await http.post(
      Uri.parse(url),
      headers: ApiConfig.headers,
      body: jsonEncode(device.toJson()),
    );
    if (response.statusCode == 201) {
      return Device.fromJson(jsonDecode(response.body));
    }
    throw Exception("Failed to create device");
  }

  Future<void> updateDevice(Device device) async {
    final response = await http.put(
      Uri.parse("$url/${device.id}"),
      headers: ApiConfig.headers,
      body: jsonEncode(device.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to update device");
    }
  }

  Future<void> deleteDevice(String id) async {
    final response = await http.delete(Uri.parse("$url/$id"));
    if (response.statusCode != 204) {
      throw Exception("Failed to delete device");
    }
  }
}