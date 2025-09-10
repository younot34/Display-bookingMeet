import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking.dart';

class BookingService {
  final CollectionReference _collection =
  FirebaseFirestore.instance.collection("bookings");
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _bookingsRef => _firestore.collection('bookings');

  Future<List<Booking>> getAllBookings() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
  }
  static Future<List<Booking>> getBookingsByRoom(String roomName) async {
    final snapshot = await FirebaseFirestore.instance
        .collection("bookings")
        .where("roomName", isEqualTo: roomName)
        .get();
    return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
  }

  Stream<List<Booking>> streamBookings({String? roomName, DateTime? date}) {
    Query query = _bookingsRef;

    if (roomName != null) {
      query = query.where('roomName', isEqualTo: roomName);
    }

    if (date != null) {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      query = query
          .where('dateTime', isGreaterThanOrEqualTo: startOfDay)
          .where('dateTime', isLessThan: endOfDay);
    }

    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => Booking.fromFirestore(doc)).toList());
  }

  Stream<List<Booking>> streamBookingsByRoom(String roomName) {
    // jika ingin order by date/time, pastikan fieldnya tersimpan dalam format
    // yang bisa di-order (mis. Timestamp / ISO), atau sesuaikan query.
    final query = _bookingsRef.where('roomName', isEqualTo: roomName);
    return query.snapshots().map((snap) {
      return snap.docs.map((doc) {
        // gunakan factory dari model Booking (harus ada)
        return Booking.fromFirestore(doc);
      }).toList();
    });
  }
  Future<Booking> saveBooking(Booking booking) async {
    final data = {
      "roomName": booking.roomName,
      "date": booking.date,
      "time": booking.time,
      "duration": booking.duration,
      "numberOfPeople": booking.numberOfPeople,
      "equipment": booking.equipment,
      "hostName": booking.hostName,
      "meetingTitle": booking.meetingTitle,
      "isScanEnabled": booking.isScanEnabled,
      "scanInfo": booking.scanInfo,
    };

    // kalau booking.id kosong → buat dokumen baru
    if (booking.id.isEmpty) {
      final docRef = await _bookingsRef.add(data);
      return booking.copyWith(id: docRef.id);
    } else {
      // kalau ada id → update
      await _bookingsRef.doc(booking.id).set(data);
      return booking;
    }
  }
  /// Pindahkan booking ke history (misal setelah selesai)
  Future<void> moveToHistory(Booking booking) async {
    final historyRef = _firestore.collection('history');
    await historyRef.doc(booking.id).set({
      "roomName": booking.roomName,
      "date": booking.date,
      "time": booking.time,
      "duration": booking.duration,
      "numberOfPeople": booking.numberOfPeople,
      "equipment": booking.equipment,
      "hostName": booking.hostName,
      "meetingTitle": booking.meetingTitle,
      "isScanEnabled": booking.isScanEnabled,
      "scanInfo": booking.scanInfo,
      "endedAt": FieldValue.serverTimestamp(),
    });
    await _bookingsRef.doc(booking.id).delete();
  }

  Future<Booking> updateBooking(Booking booking) async {
    await FirebaseFirestore.instance
        .collection("bookings")
        .doc(booking.id)
        .update(booking.toMap());
    return booking;
  }

}
