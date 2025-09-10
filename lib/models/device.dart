import 'package:cloud_firestore/cloud_firestore.dart';

class Device {
  final String id;
  final String deviceName;
  final String roomName;
  final String location;
  final DateTime installDate;
  final int capacity;
  final List<String> equipment;

  Device({
    required this.id,
    required this.deviceName,
    required this.roomName,
    required this.location,
    required this.installDate,
    required this.capacity,
    required this.equipment,
  });

  factory Device.fromFirestore(doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Device(
      id: doc.id,
      deviceName: data['deviceName'] ?? '',
      roomName: data['roomName'] ?? 'Unknown Room',
      location: data['location'] ?? '',
      installDate: data['installDate'] is Timestamp
          ? (data['installDate'] as Timestamp).toDate()
          : DateTime.now(),
      capacity: data['capacity'] ?? 0,
      equipment: List<String>.from(data['equipment'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'deviceName': deviceName,
    'roomName': roomName,
    'location': location,
    'installDate': installDate,
    'capacity': capacity,
    'equipment': equipment,
  };
}
