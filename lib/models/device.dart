import 'dart:convert';

class Device {
  final String id;
  final String deviceId;
  final String deviceName;
  final String roomName;
  final String location;
  final DateTime? installDate;
  final int capacity;
  final List<String> equipment;
  final bool isOn;

  Device({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.roomName,
    required this.location,
    required this.installDate,
    required this.capacity,
    required this.equipment,
    required this.isOn,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'].toString(),
      deviceId: json['device_id'] ?? '',
      deviceName: json['device_name'] ?? '',
      roomName: json['room_name'] ?? '',
      location: json['location'] ?? '',
      installDate: json['install_date'] != null ? DateTime.tryParse(json['install_date']) : null,
      capacity: json['capacity'] ?? 0,
      equipment: json['equipment'] != null
          ? List<String>.from(
        json['equipment'] is String
            ? jsonDecode(json['equipment'])
            : json['equipment'],
      )
          : [],
      isOn: json['is_on'] == 1 || json['is_on'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'deviceName': deviceName,
    'roomName': roomName,
    'location': location,
    'installDate': installDate,
    'capacity': capacity,
    'equipment': equipment,
    'isOn': isOn,
  };
}
