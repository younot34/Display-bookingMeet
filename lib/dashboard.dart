import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:collection/collection.dart';
import '../models/device.dart';
import '../models/booking.dart';
import '../service/booking_service.dart';
import '../service/device_service.dart';
import '../service/media_service.dart';
import 'BookingTile.dart';
import 'logo.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? logoUrlMain;
  String? logoUrlSub;

  String _dateString = "";
  String _timeString = "";

  late Timer _timer;
  late PageController _pageController;
  Timer? _pageTimer;
  int _currentPage = 0;
  int _totalPages = 1;

  final BookingService bookingService = BookingService();

  @override
  void initState() {
    super.initState();
    _loadMediaLogos();
    _startDateTimeUpdater();
    _pageController = PageController();

    _pageTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_pageController.hasClients && _totalPages > 0) {
        final nextPage = _currentPage + 1;
        if (nextPage < _totalPages) {
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
          _currentPage = nextPage;
        } else {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
          _currentPage = 0;
        }
      }
    });
  }

  Future<void> _loadMediaLogos() async {
    final mediaList = await MediaService().getAllMedia();
    if (mediaList.isNotEmpty) {
      setState(() {
        logoUrlMain = mediaList[0].logoUrl;
        logoUrlSub = mediaList[0].subLogoUrl;
      });
    }
  }

  void _startDateTimeUpdater() {
    _updateDateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateDateTime());
  }

  void _updateDateTime() {
    final now = DateTime.now();
    final newDate = DateFormat("EEEE, dd MMMM yyyy").format(now);
    final newTime = DateFormat("HH:mm").format(now);

    if (_dateString != newDate || _timeString != newTime) {
      setState(() {
        _dateString = newDate;
        _timeString = newTime;
      });
    }
  }

  @override
  void dispose() {
    _pageTimer?.cancel();
    _pageController.dispose();
    _timer.cancel();
    super.dispose();
  }

  /// ----------------------------
  /// Combine devices + bookings
  /// ----------------------------
  Stream<Map<String, dynamic>> _dashboardStream({Duration interval = const Duration(minutes: 30)}) async* {
    final devices = await DeviceService().getDevices();
    Map<String, List<Booking>> bookingsMap = {};

    // 🔹 Yield pertama → langsung tampil di UI
    final today = DateTime.now();
    for (final device in devices) {
      try {
        final bookings = await BookingService().getBookingsByRoom(device.roomName);
        bookingsMap[device.roomName] = bookings.where((b) {
          final date = _parseBookingTime(b);
          return date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;
        }).toList();
      } catch (_) {
        bookingsMap[device.roomName] = [];
      }
    }
    yield {
      "devices": devices,
      "bookingsByRoom": bookingsMap,
    };

    // 🔹 Loop auto-refresh tiap 30 menit
    await for (final _ in Stream.periodic(interval)) {
      bookingsMap = {};
      final now = DateTime.now();

      for (final device in devices) {
        try {
          final bookings = await BookingService().getBookingsByRoom(device.roomName);
          bookingsMap[device.roomName] = bookings.where((b) {
            final date = _parseBookingTime(b);
            return date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
          }).toList();
        } catch (_) {
          bookingsMap[device.roomName] = [];
        }
      }

      yield {
        "devices": devices,
        "bookingsByRoom": bookingsMap,
      };
    }
  }

  DateTime _parseBookingTime(Booking b) {
    try {
      // misalnya b.date = "2025-09-22"
      // misalnya b.time = "14:30"
      final date = DateFormat("yyyy-MM-dd").parse(b.date);
      final time = DateFormat("HH:mm").parse(b.time);

      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    } catch (e) {
      debugPrint("❌ Error parsing booking: ${b.date} ${b.time} => $e");
      return DateTime(1970, 1, 1); // fallback kosong, bukan created_at, bukan now()
    }
  }

  String _formatTime(DateTime t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  int getRowsPerPage(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height;
    final headerHeight = height * 0.10;
    final pageIndicatorHeight = 30.0;
    final availableHeight = height - headerHeight - pageIndicatorHeight - 40;
    final rowHeight = 50.0;
    return (availableHeight / rowHeight).floor();
  }

  List<Map<String, dynamic>> buildAllSlots(
      List<Device> devices, Map<String, List<Booking>> bookingsByRoom) {
    List<Map<String, dynamic>> allSlots = [];

    devices.sort((a, b) {
      return int.tryParse(a.roomName)
          ?.compareTo(int.tryParse(b.roomName) ?? 0) ??
          a.roomName.compareTo(b.roomName);
    });

    for (var i = 0; i < devices.length; i++) {
      final device = devices[i];
      final bookings = bookingsByRoom[device.roomName] ?? [];
      final slots = _buildSlots(device, bookings);

      for (var slot in slots) {
        slot["roomIndex"] = i;
      }
      allSlots.addAll(slots);
    }

    return allSlots;
  }

  List<Map<String, dynamic>> _buildSlots(Device device, List<Booking> bookings) {
    List<Map<String, dynamic>> slots = [];

    final locationParts = device.location.split(" - ");
    final building = locationParts.isNotEmpty ? locationParts[0].trim() : "";
    final floor = locationParts.length > 1 ? locationParts[1].trim() : "";
    final now = DateTime.now();
    // Jika belum ada booking sama sekali hari ini
    if (bookings.isEmpty) {
      slots.add({
        "room": device.roomName,
        "title": "Available",
        "building": building,
        "floor": floor,
        "space": device.capacity.toString(),
        "host": "",
        "status": "Available ${_formatTime(now)}-23:59",
      });
      return slots;
    }
    // Jika ada booking, lanjutkan logika slot seperti biasa
    bookings.sort((a, b) {
      final aTime = _parseBookingTime(a);
      final bTime = _parseBookingTime(b);
      return aTime.compareTo(bTime);
    });
    DateTime lastEnd = DateTime(now.year, now.month, now.day, 0, 0);

    for (var booking in bookings) {
      final start = _parseBookingTime(booking);
      final duration = int.tryParse(booking.duration ?? "0") ?? 0;
      final end = start.add(Duration(minutes: duration));

      final gapStart = lastEnd.isAfter(now) ? lastEnd : now;
      final gapEnd = start.subtract(const Duration(minutes: 30));

      if (gapStart.isBefore(gapEnd) && gapEnd.difference(gapStart).inMinutes >= 30) {
        slots.add({
          "room": device.roomName,
          "title": "Available",
          "building": building,
          "floor": floor,
          "space": device.capacity.toString(),
          "host": "",
          "status": "Available ${_formatTime(gapStart)}-${_formatTime(gapEnd)}",
        });
      }

      slots.add({
        "room": device.roomName,
        "title": booking.meetingTitle,
        "building": building,
        "floor": floor,
        "space": booking.numberOfPeople?.toString() ?? "-",
        "host": booking.hostName,
        "status": "${booking.status ?? "Ongoing"} ${_formatTime(start)}-${_formatTime(end)}",
      });

      lastEnd = end.add(const Duration(minutes: 30));
    }

    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59);
    if (lastEnd.isBefore(endOfDay)) {
      slots.add({
        "room": device.roomName,
        "title": "Available",
        "building": building,
        "floor": floor,
        "space": device.capacity.toString(),
        "host": "",
        "status": "Available ${_formatTime(lastEnd)}-${_formatTime(endOfDay)}",
      });
    }

    return slots;
  }

  List<List<Map<String, dynamic>>> paginateSlots(List<Map<String, dynamic>> slots, int rowsPerPage) {
    List<List<Map<String, dynamic>>> pages = [];
    for (var i = 0; i < slots.length; i += rowsPerPage) {
      pages.add(slots.sublist(
        i,
        (i + rowsPerPage > slots.length) ? slots.length : i + rowsPerPage,
      ));
    }
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isPortrait = media.orientation == Orientation.portrait;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LogoWidget(imageUrlOrBase64: logoUrlMain, height: 40),
                    const SizedBox(width: 8),
                    LogoWidget(imageUrlOrBase64: logoUrlSub, height: 40),
                  ],
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      "Schedule List",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: media.size.height * 0.01),
                      child: Text(
                        _dateString,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeString,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${_currentPage + 1}/$_totalPages",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // content
            Expanded(
              child: StreamBuilder<Map<String, dynamic>>(
                stream: _dashboardStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final devices = snapshot.data!["devices"] as List<Device>;
                  final bookingsByRoom = snapshot.data!["bookingsByRoom"] as Map<String, List<Booking>>;

                  if (devices.isEmpty) return const Center(child: Text("No devices found"));

                  final allSlots = buildAllSlots(devices, bookingsByRoom);
                  final rowHeight = 60.0;
                  final rowsPerPage = getRowsPerPage(context);
                  final pages = paginateSlots(allSlots, rowsPerPage);
                  _totalPages = pages.length;

                  return PageView.builder(
                    controller: _pageController,
                    itemCount: pages.length,
                    physics: isPortrait
                        ? const AlwaysScrollableScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, pageIndex) {
                      final pageSlots = pages[pageIndex];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            color: Colors.blue.shade50,
                            child: const Row(
                              children: [
                                Expanded(flex: 1, child: AutoSizeText("Room", maxLines: 1, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                                Expanded(flex: 2, child: AutoSizeText("Title", maxLines: 1, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                                Expanded(flex: 1, child: AutoSizeText("Building", maxLines: 1, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                                Expanded(flex: 1, child: AutoSizeText("Floor", maxLines: 1, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                                Expanded(flex: 1, child: AutoSizeText("Space", maxLines: 1, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                                Expanded(flex: 2, child: AutoSizeText("Host", maxLines: 1, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                                Expanded(flex: 2, child: AutoSizeText("Status", maxLines: 1, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Slots
                          Expanded(
                            child: Column(
                              children: pageSlots.mapIndexed((i, s) {
                                final isAvailable = s["title"] == "Available";
                                final status = s["status"] ?? "";
                                final roomIndex = s["roomIndex"] ?? 0;
                                final rowColor = (roomIndex % 2 == 0)
                                    ? Colors.grey.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.3);
                                Color statusBgColor = Colors.green.withOpacity(0.8);
                                if (status.startsWith("Ongoing")) statusBgColor = Colors.red.withOpacity(0.7);
                                if (status.startsWith("In Queue")) statusBgColor = Colors.yellow.withOpacity(0.8);
                                if (status.startsWith("Finished")) statusBgColor = Colors.grey.withOpacity(0.6);
                                bool isFirstInRoom = i == 0 || pageSlots[i - 1]["roomIndex"] != roomIndex;

                                return SizedBox(
                                  height: rowHeight,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: rowColor,
                                      border: isFirstInRoom
                                          ? Border(
                                        top: BorderSide(
                                          color: Colors.blueGrey.shade600,
                                          width: 2,
                                        ),
                                      )
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(flex: 1, child: AutoSizeText(s["room"] ?? "", maxLines: 1, minFontSize: 12, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                                        Expanded(flex: 2, child: AutoSizeText(s["title"] ?? "", maxLines: 1, minFontSize: 10, textAlign: TextAlign.center, style: TextStyle(color: isAvailable ? Colors.green.shade800 : Colors.black, fontWeight: FontWeight.bold, fontSize: isAvailable ? 17 : 14,))),
                                        Expanded(flex: 1, child: AutoSizeText(s["building"] ?? "", maxLines: 1, minFontSize: 10, textAlign: TextAlign.center)),
                                        Expanded(flex: 1, child: AutoSizeText(s["floor"] ?? "", maxLines: 1, minFontSize: 10, textAlign: TextAlign.center)),
                                        Expanded(flex: 1, child: AutoSizeText(s["space"] ?? "", maxLines: 1, minFontSize: 10, textAlign: TextAlign.center)),
                                        Expanded(flex: 2, child: AutoSizeText(s["host"] ?? "", maxLines: 1, minFontSize: 10, textAlign: TextAlign.center)),
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                            decoration: BoxDecoration(
                                              color: statusBgColor,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: AutoSizeText(status, maxLines: 1, minFontSize: 10, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
