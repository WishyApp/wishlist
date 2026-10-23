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
  late final FixedExtentScrollController _dayController =
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
    final dayChanged = day != _day;
    setState(() {
      _month = month;
      _day = day;
    });
    if (dayChanged) {
      // The wheel length changed: put it on the displayed day.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _dayController.hasClients) {
          _dayController.jumpToItem(_day - 1);
        }
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
            child: CupertinoPicker.builder(
              key: const ValueKey('birthday-day-picker'),
              scrollController: _dayController,
              itemExtent: _itemExtent,
              childCount: Birthday.daysInMonth(_month),
              onSelectedItemChanged: _onDayChanged,
              itemBuilder: (context, index) => Center(
                child: Text('${index + 1}'),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: CupertinoPicker(
              key: const ValueKey('birthday-month-picker'),
              scrollController: _monthController,
              itemExtent: _itemExtent,
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
