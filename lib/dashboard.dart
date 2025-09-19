import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loby/service/booking_service.dart';
import 'package:loby/service/device_service.dart';
import 'package:loby/service/media_service.dart';
import '../models/device.dart';
import '../models/booking.dart';
import 'BookingTile.dart';
import 'logo.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:collection/collection.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String selectedMenu = "Reporting";
  String? selectedRoom;
  DateTime? selectedDate;
  List<Device> devices = [];
  Map<String, List<Booking>> bookingsByRoom = {};
  final BookingService bookingService = BookingService();
  String? logoUrlMain;
  String? logoUrlSub;
  late Timer _timer;
  String _dateString = "";
  String _timeString = "";
  late final Stream<int> _clockStream;
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _pageTimer;
  int _totalPages = 1;

  Future<void> _loadMediaLogos() async {
    final mediaList = await MediaService().getAllMedia();
    if (mediaList.isNotEmpty) {
      setState(() {
        logoUrlMain = mediaList[0].logoUrl;
        logoUrlSub = mediaList[0].subLogoUrl;
      });
    }
  }

  List<Map<String, dynamic>> buildAllSlots(List<Device> devices,
      Map<String, List<Booking>> bookingsByRoom) {
    List<Map<String, dynamic>> allSlots = [];

    devices.sort((a, b) {
      return int.tryParse(a.roomName)?.compareTo(
          int.tryParse(b.roomName) ?? 0) ??
          a.roomName.compareTo(b.roomName);
    });

    for (var i = 0; i < devices.length; i++) {
      final device = devices[i];
      final bookings = bookingsByRoom[device.roomName] ?? [];
      final slots = buildSlots(device, bookings);

      for (var slot in slots) {
        slot["roomIndex"] = i;
      }
      allSlots.addAll(slots);
    }
    return allSlots;
  }

  List<List<Map<String, dynamic>>> paginateSlots(
      List<Map<String, dynamic>> slots, int rowsPerPage) {
    List<List<Map<String, dynamic>>> pages = [];
    for (var i = 0; i < slots.length; i += rowsPerPage) {
      pages.add(slots.sublist(
        i,
        (i + rowsPerPage > slots.length) ? slots.length : i + rowsPerPage,
      ));
    }
    return pages;
  }

  List<Map<String, dynamic>> buildSlots(Device device, List<Booking> bookings) {
    List<Map<String, dynamic>> slots = [];

    final locationParts = device.location.split(" - ");
    final building = locationParts.isNotEmpty ? locationParts[0].trim() : "";
    final floor = locationParts.length > 1 ? locationParts[1].trim() : "";

    bookings.sort((a, b) {
      final aTime = _parseBookingTime(a);
      final bTime = _parseBookingTime(b);
      return aTime.compareTo(bTime);
    });

    final now = DateTime.now();
    DateTime lastEnd = DateTime(now.year, now.month, now.day, 0, 0);

    if (bookings.isEmpty) {
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59);
      final durationMinutes = endOfDay.difference(now).inMinutes;
      if (durationMinutes >= 30) {
        slots.add({
          "room": device.roomName,
          "title": "Available",
          "building": building,
          "floor": floor,
          "space": device.capacity.toString(),
          "host": "",
          "status": "Available         now-${_formatTime(endOfDay)}",
        });
      }
      return slots;
    }

    for (var booking in bookings) {
      final start = _parseBookingTime(booking);
      final duration = int.tryParse(booking.duration ?? "0") ?? 0;
      final end = start.add(Duration(minutes: duration));
      final gapStart = lastEnd.isAfter(now) ? lastEnd : now;
      final gapEnd = start.subtract(const Duration(minutes: 30));
      if (gapStart.isBefore(gapEnd)) {
        final availableDuration = gapEnd.difference(gapStart).inMinutes;
        if (availableDuration >= 30) {
          slots.add({
            "room": device.roomName,
            "title": "Available",
            "building": building,
            "floor": floor,
            "space": device.capacity.toString(),
            "host": "",
            "status": "Available      ${_formatTime(gapStart)}-${_formatTime(gapEnd)}",
          });
        }
      }

      slots.add({
        "room": device.roomName,
        "title": booking.meetingTitle,
        "building": building,
        "floor": floor,
        "space": booking.numberOfPeople?.toString() ?? "-",
        "host": booking.hostName,
        "status":
        "${getBookingStatus(booking)}      ${_formatTime(start)}-${_formatTime(end)}",
      });

      lastEnd = end.add(const Duration(minutes: 30));
    }

    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59);
    if (lastEnd.isBefore(endOfDay)) {
      final gapStart = lastEnd.isAfter(now) ? lastEnd : now;
      final availableDuration = endOfDay.difference(gapStart).inMinutes;
      if (availableDuration >= 30) {
        slots.add({
          "room": device.roomName,
          "title": "Available",
          "building": building,
          "floor": floor,
          "space": device.capacity.toString(),
          "host": "",
          "status": "Available      ${_formatTime(gapStart)}-${_formatTime(endOfDay)}",
        });
      }
    }
    return slots;
  }

  DateTime _parseBookingTime(Booking b) {
    final parts = b.date.split("/");
    final d = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final y = int.parse(parts[2]);
    final t = b.time.split(":");
    final h = int.parse(t[0]);
    final min = int.parse(t[1]);

    return DateTime(y, m, d, h, min);
  }

  String _formatTime(DateTime t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(
          2, '0')}";

  void _checkAndMoveFinishedBookings() async {
    final now = DateTime.now();

    for (var roomBookings in bookingsByRoom.values) {
      for (var booking in roomBookings) {
        final startTime = _parseBookingTime(booking);
        final durationMinutes = int.tryParse(booking.duration ?? "0") ?? 0;
        final endTime = startTime.add(Duration(minutes: durationMinutes));

        if (now.isAfter(endTime)) {
          try {
            await bookingService.endBooking(int.parse(booking.id));
            print("Booking ${booking.id} dipindahkan ke history (sudah selesai).");
          } catch (e) {
            print("Gagal memindahkan booking ${booking.id} ke history: $e");
          }
        }
      }
    }
  }

  String getBookingStatus(Booking booking) {
    final now = DateTime.now();

    final dateParts = booking.date.split("/");
    final day = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final year = int.parse(dateParts[2]);

    final startTimeParts = booking.time.split(":");
    final startHour = int.parse(startTimeParts[0]);
    final startMinute = int.parse(startTimeParts[1]);
    final startTime = DateTime(year, month, day, startHour, startMinute);

    final durationMinutes = int.tryParse(booking.duration ?? "0") ?? 0;
    final endTime = startTime.add(Duration(minutes: durationMinutes));

    if (now.isAfter(startTime) && now.isBefore(endTime)) {
      return "Ongoing";
    } else if (now.isBefore(startTime)) {
      return "In Queue";
    } else {
      return "Finished";
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMediaLogos();
    _startDateTimeUpdater();
    _clockStream = Stream.periodic(const Duration(seconds: 1), (i) => i);
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
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      _checkAndMoveFinishedBookings();
      setState(() {});
    });
  }

  void _startDateTimeUpdater() {
    _updateDateTime();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateDateTime());
  }

  void _updateDateTime() {
    final now = DateTime.now();
    _dateString = DateFormat("EEEE, dd MMMM yyyy").format(now);
    _timeString = DateFormat("HH:mm").format(now);
    setState(() {});
  }

  @override
  void dispose() {
    _pageTimer?.cancel();
    _pageController.dispose();
    _timer.cancel();
    super.dispose();
  }

  int getRowsPerPage(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height;
    final orientation = media.orientation;

    final headerHeight = height * 0.10;
    final pageIndicatorHeight = 30.0;
    final availableHeight = height - headerHeight - pageIndicatorHeight - 40;
    final rowHeight = 50.0;
    return (availableHeight / rowHeight).floor();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _buildMainContent(),
      ),
    );
  }

  Widget _buildMainContent() {
    final media = MediaQuery.of(context);
    final isPortrait = media.orientation == Orientation.portrait;

    return Column(
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
          child: StreamBuilder<List<Device>>(
            stream: DeviceService().getDevicesStream(),
            builder: (context, deviceSnapshot) {
              final devices = deviceSnapshot.data ?? [];
              if (devices.isEmpty)
                return const Center(child: CircularProgressIndicator());

              return StreamBuilder<Map<String, List<Booking>>>(
                stream: _bookingsByDeviceStream(devices),
                builder: (context, bookingSnapshot) {
                  final bookingsByRoom = bookingSnapshot.data ?? {};
                  final rowHeight = 60.0;
                  final allSlots = buildAllSlots(devices, bookingsByRoom);


                  final availableHeight = media.size.height -
                      (media.size.height * 0.10) -
                      30 -
                      40;
                  final rowsPerPage = (availableHeight / rowHeight).floor();

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
                              children: pageSlots
                                  .mapIndexed((i, s) {
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
                                bool isFirstInRoom = false;
                                if (i == 0) {
                                  isFirstInRoom = true;
                                } else {
                                  final prevRoom = pageSlots[i - 1]["roomIndex"];
                                  if (prevRoom != roomIndex) {
                                    isFirstInRoom = true;
                                  }
                                }

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
              );
            },
          ),
        ),
      ],
    );
  }
  Stream<Map<String, List<Booking>>> _bookingsByDeviceStream(List<Device> devices)
  {
    if (devices.isEmpty) return Stream.value({});
    final today = DateTime.now();
    final streams = devices.map((device) =>
        bookingService.streamBookingsByRoom(device.roomName)
            .map((bookings) {
          // filter booking hari ini
          final todayBookings = bookings.where((b) {
            final bookingDate = _parseBookingTime(b);
            return bookingDate.year == today.year &&
                bookingDate.month == today.month &&
                bookingDate.day == today.day;
          }).toList();

          return MapEntry(device.roomName, todayBookings);
        })
    );

    return CombineLatestStream.list<MapEntry<String, List<Booking>>>(streams)
        .map((entries) {
      final map = <String, List<Booking>>{};
      for (var entry in entries) {
        map[entry.key] = entry.value;
      }
      return map;
    });
  }
}
