import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/booking.dart';

class BookingService {
  final String url = "${ApiConfig.baseUrl}/bookings";

  Future<List<Booking>> getBookingsByRoom(String roomName) async {
    final response = await http.get(Uri.parse("${ApiConfig.baseUrl}/bookings/room/$roomName"));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Booking.fromJson(e)).toList();
    }
    throw Exception("Failed to fetch bookings by room");
  }

  Stream<List<Booking>> streamBookingsByRoom(String roomName, {Duration interval = const Duration(seconds: 1)}) async* {
    yield await getBookingsByRoom(roomName); // tampil cepat pertama kali
    yield* Stream.periodic(interval).asyncMap((_) => getBookingsByRoom(roomName));
  }

  Future<Booking> createBooking(Booking booking) async {
    final response = await http.post(
      Uri.parse(url),
      headers: ApiConfig.headers,
      body: jsonEncode(booking.toJson()),
    );
    if (response.statusCode == 201) {
      return Booking.fromJson(jsonDecode(response.body));
    }
    print("JSON dikirim: ${booking.toJson()}");
    throw Exception("Failed to create booking");
  }

  Future<Booking> updateBooking(Booking booking) async {
    final response = await http.put(
      Uri.parse("$url/${booking.id}"),
      headers: ApiConfig.headers,
      body: jsonEncode(booking.toJson()),
    );
    if (response.statusCode == 200) {
      return Booking.fromJson(jsonDecode(response.body));
    }
    throw Exception("Failed to update booking");
  }

  Future<void> deleteBooking(int id) async {
    final response = await http.delete(Uri.parse("$url/$id"));
    if (response.statusCode != 204) {
      throw Exception("Failed to delete booking");
    }
  }

  Future<Booking> saveBooking(Booking booking) async {
    return await createBooking(booking);
  }

  Future<void> endBooking(int id) async {
    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/bookings/$id/end"),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      print("Failed to end booking, status: ${response.statusCode}, body: ${response.body}");
      throw Exception("Failed to end booking");
    }
  }
}