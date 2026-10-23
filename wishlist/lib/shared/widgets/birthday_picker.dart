import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';

/// Two wheels, day then month, to pick a birthday without a year.
///
/// The day wheel only goes up to the number of days of the selected month
/// (29 for February). When the month changes and the day no longer exists, the
/// day moves to the last day of the new month. The day the user picked is
/// remembered: January 31, February, then March gives back 31.
///
/// Both wheels loop, like the iOS date picker: there are always values above
/// and below the selected one.
///
/// [initialValue] is only read when the picker is created. To reset the picker
/// to another value, give it another [Key]: the state, the wheels included, is
/// then built again.
class BirthdayPicker extends StatefulWidget {
  const BirthdayPicker({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  final Birthday initialValue;
  final ValueChanged<Birthday> onChanged;

  @override
  State<BirthdayPicker> createState() => _BirthdayPickerState();
}

class _BirthdayPickerState extends State<BirthdayPicker> {
  static const _itemExtent = 40.0;

  late int _month = widget.initialValue.month;
  late int _day = widget.initialValue.day;

  /// The day picked on the wheel (or the initial one), whatever the month.
  late int _requestedDay = widget.initialValue.day;
  late FixedExtentScrollController _dayController =
      FixedExtentScrollController(initialItem: _day - 1);
  late final FixedExtentScrollController _monthController =
      FixedExtentScrollController(initialItem: _month - 1);

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  void _onDayChanged(int index) {
    // The wheel also reports the moves made by the month change (shorter or
    // longer wheel, jump back to the remembered day): not a pick.
    if (index + 1 == _day) {
      return;
    }
    _day = index + 1;
    _requestedDay = _day;
    widget.onChanged(Birthday(month: _month, day: _day));
  }

  void _onMonthChanged(int index) {
    final month = index + 1;
    final day = math.min(_requestedDay, Birthday.daysInMonth(month));
    final rebuildDayWheel =
        Birthday.daysInMonth(month) != Birthday.daysInMonth(_month) ||
            day != _day;
    final oldController = _dayController;
    setState(() {
      _month = month;
      _day = day;
      if (rebuildDayWheel) {
        // A looping wheel maps its position modulo its length: once the length
        // changes, the same position shows another day. A new wheel, built on
        // the displayed day, never shows a wrong one, not even for a frame.
        _dayController = FixedExtentScrollController(initialItem: _day - 1);
      }
    });
    if (rebuildDayWheel) {
      // Still attached to the old wheel until this frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController.dispose();
      });
    }
    widget.onChanged(Birthday(month: _month, day: _day));
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final monthFormat = DateFormat.MMMM(locale);

    // The wheels take their text style from the Cupertino theme, which
    // defaults to the platform font: use the app's instead.
    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(
        textTheme: CupertinoTextThemeData(
          pickerTextStyle: AppTextStyles.large.copyWith(
            color: AppColors.darkGrey,
          ),
        ),
      ),
      child: _buildWheels(monthFormat),
    );
  }

  Widget _buildWheels(DateFormat monthFormat) {
    return SizedBox(
      height: 180,
      child: Row(
        children: [
          Expanded(
            // A new wheel for each controller (see _onMonthChanged)
            child: KeyedSubtree(
              key: ValueKey(_dayController),
              child: CupertinoPicker(
                key: const ValueKey('birthday-day-picker'),
                scrollController: _dayController,
                itemExtent: _itemExtent,
                looping: true,
                onSelectedItemChanged: _onDayChanged,
                children: [
                  for (var day = 1; day <= Birthday.daysInMonth(_month); day++)
                    Center(child: Text('$day')),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: CupertinoPicker(
              key: const ValueKey('birthday-month-picker'),
              scrollController: _monthController,
              itemExtent: _itemExtent,
              looping: true,
              onSelectedItemChanged: _onMonthChanged,
              children: [
                for (var month = 1; month <= 12; month++)
                  Center(
                    child: Text(monthFormat.format(DateTime(2024, month))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
