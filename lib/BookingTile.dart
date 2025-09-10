import 'dart:async';
import 'package:flutter/material.dart';
import '../models/booking.dart';

class BookingTile extends StatefulWidget {
  final Booking booking;
  BookingTile({required this.booking});

  @override
  State<BookingTile> createState() => _BookingTileState();
}

class _BookingTileState extends State<BookingTile> {
  late Timer timer;

  @override
  void initState() {
    super.initState();
    // Timer setiap 1 detik untuk update status
    timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateParts = widget.booking.date.split("/");
    final day = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final year = int.parse(dateParts[2]);

    final startTimeParts = widget.booking.time.split(":");
    final startHour = int.parse(startTimeParts[0]);
    final startMinute = int.parse(startTimeParts[1]);
    final startTime = DateTime(year, month, day, startHour, startMinute);

    final durationMinutes = int.tryParse(widget.booking.duration ?? "0") ?? 0;
    final endTime = startTime.add(Duration(minutes: durationMinutes));

    final isOngoing = now.isAfter(startTime) && now.isBefore(endTime);

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_note, color: Color(0xFF5C6BC0)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              widget.booking.meetingTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOngoing ? Colors.red.shade100 : Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isOngoing ? "Ongoing" : "In Queue",
              style: TextStyle(
                color: isOngoing ? Colors.red : Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        "${widget.booking.time} • ${widget.booking.hostName}",
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}