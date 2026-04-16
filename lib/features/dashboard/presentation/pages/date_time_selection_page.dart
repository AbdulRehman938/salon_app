import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/booking_selection_service.dart';
import 'booking_summary_page.dart';

class DateTimeSelectionPage extends StatefulWidget {
  const DateTimeSelectionPage({
    super.key,
    required this.salonId,
    required this.openingDays,
    required this.openingTiming,
    required this.discountOffer,
  });

  final String salonId;
  final String openingDays;
  final String openingTiming;
  final String discountOffer;

  @override
  State<DateTimeSelectionPage> createState() => _DateTimeSelectionPageState();
}

class _DateTimeSelectionPageState extends State<DateTimeSelectionPage> {
  final BookingSelectionService _bookingSelectionService =
      BookingSelectionService();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  late List<DateTime> _displayDates;
  late final List<TimeOfDay> _timeSlots;
  late final _DiscountWindow? _discountWindow;
  late final DateTime _minSelectableDate;
  late final DateTime _maxSelectableDateExclusive;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _minSelectableDate = DateTime(now.year, now.month, now.day);
    _maxSelectableDateExclusive = _addMonths(_minSelectableDate, 2);
    _displayDates = <DateTime>[
      DateTime(now.year, now.month, now.day),
      DateTime(now.year, now.month, now.day + 1),
      DateTime(now.year, now.month, now.day + 2),
    ];
    _timeSlots = _buildTimeSlots(widget.openingTiming);
    _discountWindow = _parseDiscountWindow(widget.discountOffer);

    for (final date in _displayDates) {
      if (_isSelectableDate(date)) {
        _selectedDate = date;
        _displayDates = _nextThreeDates(date);
        break;
      }
    }
  }

  bool get _canConfirm => _selectedDate != null && _selectedTime != null;

  String _weekdayShort(DateTime date) {
    const labels = <int, String>{
      DateTime.monday: 'MON',
      DateTime.tuesday: 'TUE',
      DateTime.wednesday: 'WED',
      DateTime.thursday: 'THU',
      DateTime.friday: 'FRI',
      DateTime.saturday: 'SAT',
      DateTime.sunday: 'SUN',
    };
    return labels[date.weekday] ?? '';
  }

  String _monthDayLabel(DateTime date) {
    const months = <int, String>{
      1: 'Jan',
      2: 'Feb',
      3: 'Mar',
      4: 'Apr',
      5: 'May',
      6: 'Jun',
      7: 'Jul',
      8: 'Aug',
      9: 'Sep',
      10: 'Oct',
      11: 'Nov',
      12: 'Dec',
    };
    return '${months[date.month]} ${date.day}';
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  int _toMinutes(TimeOfDay time) {
    return (time.hour * 60) + time.minute;
  }

  bool _isDateOpen(DateTime date) {
    final normalized = widget.openingDays.toLowerCase().trim();
    if (normalized.isEmpty || normalized.contains('monday - sunday')) {
      return true;
    }

    final dayName = _fullDayName(date.weekday).toLowerCase();

    if (normalized.contains('-')) {
      final parts = normalized.split('-').map((p) => p.trim()).toList();
      if (parts.length == 2) {
        final start = _weekdayFromName(parts[0]);
        final end = _weekdayFromName(parts[1]);
        if (start != null && end != null) {
          if (start <= end) {
            return date.weekday >= start && date.weekday <= end;
          }
          return date.weekday >= start || date.weekday <= end;
        }
      }
    }

    final tokens = normalized
        .split(RegExp(r'[,/&]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return true;
    }

    for (final token in tokens) {
      final weekday = _weekdayFromName(token);
      if (weekday == date.weekday) {
        return true;
      }
    }

    return dayName.contains(normalized);
  }

  int? _weekdayFromName(String value) {
    final normalized = value.toLowerCase();
    if (normalized.startsWith('mon')) return DateTime.monday;
    if (normalized.startsWith('tue')) return DateTime.tuesday;
    if (normalized.startsWith('wed')) return DateTime.wednesday;
    if (normalized.startsWith('thu')) return DateTime.thursday;
    if (normalized.startsWith('fri')) return DateTime.friday;
    if (normalized.startsWith('sat')) return DateTime.saturday;
    if (normalized.startsWith('sun')) return DateTime.sunday;
    return null;
  }

  String _fullDayName(int weekday) {
    const names = <int, String>{
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };
    return names[weekday] ?? '';
  }

  DateTime _addMonths(DateTime date, int monthDelta) {
    final totalMonths = (date.year * 12) + (date.month - 1) + monthDelta;
    final year = totalMonths ~/ 12;
    final month = (totalMonths % 12) + 1;
    final lastDayOfTargetMonth = DateTime(year, month + 1, 0).day;
    final day = date.day <= lastDayOfTargetMonth
        ? date.day
        : lastDayOfTargetMonth;
    return DateTime(year, month, day);
  }

  bool _isWithinAllowedDateWindow(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return !normalized.isBefore(_minSelectableDate) &&
        normalized.isBefore(_maxSelectableDateExclusive);
  }

  bool _isSelectableDate(DateTime date) {
    return _isWithinAllowedDateWindow(date) && _isDateOpen(date);
  }

  List<DateTime> _nextThreeDates(DateTime fromDate) {
    return <DateTime>[
      DateTime(fromDate.year, fromDate.month, fromDate.day),
      DateTime(fromDate.year, fromDate.month, fromDate.day + 1),
      DateTime(fromDate.year, fromDate.month, fromDate.day + 2),
    ];
  }

  Future<void> _openMoreDatesSheet() async {
    final pickedDate = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.45,
          child: _CalendarBottomSheet(
            initialDate: _selectedDate ?? _minSelectableDate,
            minDate: _minSelectableDate,
            maxDateExclusive: _maxSelectableDateExclusive,
            selectedDate: _selectedDate,
            isDateOpen: _isDateOpen,
          ),
        );
      },
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = pickedDate;
      _displayDates = _nextThreeDates(pickedDate);
    });
  }

  List<TimeOfDay> _buildTimeSlots(String openingTiming) {
    final parts = openingTiming.split('-');
    if (parts.length != 2) {
      return const <TimeOfDay>[];
    }

    final start = _parseTime(parts[0].trim());
    final end = _parseTime(parts[1].trim());
    if (start == null || end == null) {
      return const <TimeOfDay>[];
    }

    var startMinutes = _toMinutes(start);
    var endMinutes = _toMinutes(end);
    if (endMinutes < startMinutes) {
      endMinutes += 24 * 60;
    }

    final slots = <TimeOfDay>[];
    for (var current = startMinutes; current <= endMinutes; current += 30) {
      final minuteOfDay = current % (24 * 60);
      slots.add(TimeOfDay(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60));
    }

    return slots;
  }

  TimeOfDay? _parseTime(String value) {
    final match = RegExp(
      r'^(\d{1,2})(?::(\d{2}))?\s*([AP]M)$',
      caseSensitive: false,
    ).firstMatch(value.trim());

    if (match == null) {
      return null;
    }

    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '0');
    final period = (match.group(3) ?? '').toUpperCase();

    if (hour == null || minute == null || hour < 1 || hour > 12) {
      return null;
    }

    var normalizedHour = hour % 12;
    if (period == 'PM') {
      normalizedHour += 12;
    }

    return TimeOfDay(hour: normalizedHour, minute: minute);
  }

  _DiscountWindow? _parseDiscountWindow(String offer) {
    final normalized = offer.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final match = RegExp(
      r'(\d{1,2})\s*%\s*off\s*between\s*([0-9: ]+[AP]M)\s*-\s*([0-9: ]+[AP]M)',
      caseSensitive: false,
    ).firstMatch(normalized);

    if (match == null) {
      return null;
    }

    final percent = int.tryParse(match.group(1) ?? '');
    final start = _parseTime((match.group(2) ?? '').trim());
    final end = _parseTime((match.group(3) ?? '').trim());

    if (percent == null || start == null || end == null) {
      return null;
    }

    return _DiscountWindow(percent: percent, start: start, end: end);
  }

  bool _isDiscountTime(TimeOfDay time) {
    final discount = _discountWindow;
    if (discount == null) {
      return false;
    }

    final timeMinutes = _toMinutes(time);
    var startMinutes = _toMinutes(discount.start);
    var endMinutes = _toMinutes(discount.end);

    if (endMinutes < startMinutes) {
      endMinutes += 24 * 60;
    }

    var current = timeMinutes;
    if (current < startMinutes) {
      current += 24 * 60;
    }

    return current >= startMinutes && current < endMinutes;
  }

  Future<void> _onConfirmTap() async {
    if (!_canConfirm || _selectedDate == null || _selectedTime == null) {
      return;
    }

    await _bookingSelectionService.saveDateTimeSelection(
      salonId: widget.salonId,
      dateIso: _selectedDate!.toIso8601String(),
      timeLabel: _formatTime(_selectedTime!),
      discountPercent: _isDiscountTime(_selectedTime!)
          ? _discountWindow?.percent
          : null,
    );

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingSummaryPage(salonId: widget.salonId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 84, 16, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Date',
                    style: TextStyle(
                      color: AppColors.dark1,
                      fontSize: 34 / 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ..._displayDates.map((date) {
                        final isOpen = _isSelectableDate(date);
                        final isSelected =
                            _selectedDate != null &&
                            _sameDate(_selectedDate!, date);

                        return Expanded(
                          child: GestureDetector(
                            onTap: isOpen
                                ? () {
                                    setState(() {
                                      _selectedDate = date;
                                    });
                                  }
                                : null,
                            child: Opacity(
                              opacity: isOpen ? 1 : 0.42,
                              child: Container(
                                height: 92,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF2F57F0)
                                        : const Color(0xFFEAEAEA),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _weekdayShort(date),
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF2F57F0)
                                            : AppColors.gray1,
                                        fontSize: 24 / 2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _monthDayLabel(date),
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF2F57F0)
                                            : AppColors.dark1,
                                        fontSize: 30 / 2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '40 mins',
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF2F57F0)
                                            : AppColors.gray1,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      Expanded(
                        child: GestureDetector(
                          onTap: _openMoreDatesSheet,
                          child: Container(
                            height: 92,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFEAEAEA),
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 19,
                                  color: AppColors.dark1,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'More\ndates',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.dark1,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'Select Time',
                    style: TextStyle(
                      color: AppColors.dark1,
                      fontSize: 34 / 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ..._timeSlots.map((time) {
                    final isSelected =
                        _selectedTime != null &&
                        _toMinutes(_selectedTime!) == _toMinutes(time);
                    final hasDiscount = _isDiscountTime(time);

                    return GestureDetector(
                      onTap: _selectedDate == null
                          ? null
                          : () {
                              setState(() {
                                _selectedTime = time;
                              });
                            },
                      child: Container(
                        height: 56,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2F57F0)
                                : const Color(0xFFEDEDED),
                            width: isSelected ? 1.3 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _formatTime(time),
                              style: const TextStyle(
                                color: AppColors.dark1,
                                fontSize: 31 / 2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (hasDiscount)
                              Text(
                                '${_discountWindow!.percent}% Off',
                                style: const TextStyle(
                                  color: Color(0xFF20B169),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              child: SafeArea(
                bottom: false,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.78),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: AppColors.dark1,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Date and time',
                              style: TextStyle(
                                color: AppColors.dark1,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _canConfirm ? _onConfirmTap : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _canConfirm
                          ? const Color(0xFF2F57F0)
                          : const Color(0xFFC8C8CB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Confirm Appointment',
                      style: TextStyle(
                        fontSize: 31 / 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscountWindow {
  const _DiscountWindow({
    required this.percent,
    required this.start,
    required this.end,
  });

  final int percent;
  final TimeOfDay start;
  final TimeOfDay end;
}

class _CalendarBottomSheet extends StatelessWidget {
  const _CalendarBottomSheet({
    required this.initialDate,
    required this.minDate,
    required this.maxDateExclusive,
    required this.selectedDate,
    required this.isDateOpen,
  });

  final DateTime initialDate;
  final DateTime minDate;
  final DateTime maxDateExclusive;
  final DateTime? selectedDate;
  final bool Function(DateTime date) isDateOpen;

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isWithinRange(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return !normalized.isBefore(minDate) &&
        normalized.isBefore(maxDateExclusive);
  }

  List<DateTime> _monthsInRange() {
    final months = <DateTime>[];
    var cursor = DateTime(minDate.year, minDate.month, 1);
    final end = DateTime(
      maxDateExclusive.year,
      maxDateExclusive.month,
      maxDateExclusive.day,
    );

    while (!cursor.isAfter(end)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return months;
  }

  String _monthYearLabel(DateTime date) {
    const months = <int, String>{
      1: 'January',
      2: 'February',
      3: 'March',
      4: 'April',
      5: 'May',
      6: 'June',
      7: 'July',
      8: 'August',
      9: 'September',
      10: 'October',
      11: 'November',
      12: 'December',
    };
    return '${months[date.month]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final months = _monthsInRange();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 56,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFC9C9C9),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'Sun',
                      style: TextStyle(
                        color: Color(0xFF8F8F8F),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Mon',
                      style: TextStyle(
                        color: Color(0xFF8F8F8F),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Tue',
                      style: TextStyle(
                        color: Color(0xFF8F8F8F),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Wed',
                      style: TextStyle(
                        color: Color(0xFF8F8F8F),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Thu',
                      style: TextStyle(
                        color: Color(0xFF8F8F8F),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Fri',
                      style: TextStyle(
                        color: Color(0xFF8F8F8F),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Sat',
                      style: TextStyle(
                        color: Color(0xFF8F8F8F),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
              itemCount: months.length,
              itemBuilder: (context, index) {
                final month = months[index];
                final firstDay = DateTime(month.year, month.month, 1);
                final daysInMonth = DateTime(
                  month.year,
                  month.month + 1,
                  0,
                ).day;
                final leadingEmptyCells = firstDay.weekday % 7;
                final totalCells = leadingEmptyCells + daysInMonth;
                final rows = (totalCells / 7).ceil();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _monthYearLabel(month),
                            style: const TextStyle(
                              color: Color(0xFF5F5F5F),
                              fontSize: 34 / 2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Divider(
                              color: Color(0xFFD7D7D7),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: rows * 44,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rows * 7,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                childAspectRatio: 1,
                              ),
                          itemBuilder: (context, gridIndex) {
                            final dayNumber = gridIndex - leadingEmptyCells + 1;
                            if (dayNumber < 1 || dayNumber > daysInMonth) {
                              return const SizedBox.shrink();
                            }

                            final date = DateTime(
                              month.year,
                              month.month,
                              dayNumber,
                            );
                            final inRange = _isWithinRange(date);
                            final open = isDateOpen(date);
                            final enabled = inRange && open;
                            final selected =
                                selectedDate != null &&
                                _sameDate(selectedDate!, date);

                            return GestureDetector(
                              onTap: enabled
                                  ? () => Navigator.of(context).pop(date)
                                  : null,
                              child: Center(
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFFDDE5FF)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$dayNumber',
                                    style: TextStyle(
                                      color: selected
                                          ? const Color(0xFF2F57F0)
                                          : enabled
                                          ? AppColors.dark1
                                          : const Color(0xFFB6B6B6),
                                      fontSize: 16,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
