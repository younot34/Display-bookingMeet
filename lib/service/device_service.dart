import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device.dart';

class DeviceFirestoreService {
  final CollectionReference _collection =
  FirebaseFirestore.instance.collection("devices");

  Future<String> getLocation(String deviceName) async {
    try {
      final snapshot = await _collection
          .where("name", isEqualTo: deviceName) // pastikan field "name" sama dengan nama device
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        return data["location"] ?? "Unknown Location";
      } else {
        return "Unknown Location";
      }
    } catch (e) {
      print("Failed to get location: $e");
      return "Unknown Location";
    }
  }

  Stream<String> streamDeviceLocation(String deviceName) {
    return _collection
        .where("name", isEqualTo: deviceName)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        return data["location"] ?? "Unknown Location";
      } else {
        return "Unknown Location";
      }
    });
  }
  final CollectionReference devicesCollection =
  FirebaseFirestore.instance.collection("devices");

  Future<List<Device>> getDevices() async {
    final snapshot = await devicesCollection.get();
    return snapshot.docs.map((doc) => Device.fromFirestore(doc)).toList();
  }

  Stream<List<Device>> getDevicesStream() {
    return FirebaseFirestore.instance
        .collection('devices')
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Device.fromFirestore(doc)).toList());
  }

  Future<void> createDevice(Device device) async {
    await devicesCollection.add(device.toMap());
  }

  Future<void> updateDevice(Device device) async {
    await devicesCollection.doc(device.id).update(device.toMap());
  }

  Future<void> deleteDevice(String id) async {
    await devicesCollection.doc(id).delete();
  }
}