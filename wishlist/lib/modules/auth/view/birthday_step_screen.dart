import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/current_user_birthday_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/utils/app_snackbar.dart';
import 'package:wishlist/shared/widgets/birthday_picker.dart';

/// Optional step of the signup, right after the pseudo: the user can give
/// their birthday or skip it. Never forced: only the pseudo screen leads here.
class BirthdayStepScreen extends ConsumerStatefulWidget {
  const BirthdayStepScreen({
    super.key,
    this.redirectTo,
  });

  /// The deep link the user came from, opened once the step is done.
  final String? redirectTo;

  @override
  ConsumerState<BirthdayStepScreen> createState() => _BirthdayStepScreenState();
}

class _BirthdayStepScreenState extends ConsumerState<BirthdayStepScreen> {
  static const _defaultBirthday = Birthday(month: 1, day: 1);

  Birthday _selected = _defaultBirthday;
  bool _isSaving = false;

  void _goNext() {
    final redirectTo = widget.redirectTo;

    if (redirectTo != null && redirectTo.startsWith('/')) {
      context.go(redirectTo);
    } else {
      HomeRoute().go(context);
    }
  }

  Future<void> _onSave() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(userServiceProvider).upsertCurrentUserBirthday(_selected);
      // The settings line shows the new value
      ref.invalidate(currentUserBirthdayProvider);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _goNext();
      }
    } on AppException catch (appException) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        showGenericError(context, error: appException);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Small screens (iPhone 8 / SE) scroll: keep the illustration modest
    final illustrationHeight =
        (MediaQuery.sizeOf(context).height / 5).clamp(100.0, 200.0);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              32,
              math.min(32, illustrationHeight / 3),
              32,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SvgPicture.asset(
                  Assets.svg.birthday,
                  height: illustrationHeight,
                ),
                const Gap(24),
                Text(
                  l10n.birthdayStepTitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title,
                ),
                const Gap(8),
                Text(
                  l10n.birthdayStepExplanation,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.small.copyWith(color: AppColors.makara),
                ),
                const Gap(16),
                BirthdayPicker(
                  initialValue: _selected,
                  onChanged: (value) => _selected = value,
                ),
                const Gap(24),
                PrimaryButton(
                  text: l10n.changeBirthdayConfirm,
                  onPressed: _isSaving ? null : _onSave,
                  isLoading: _isSaving,
                  style: BaseButtonStyle.large,
                ),
                const Gap(8),
                TextButton(
                  onPressed: _isSaving ? null : _goNext,
                  child: Text(
                    l10n.birthdayStepLater,
                    style: AppTextStyles.small.copyWith(
                      color: AppColors.makara,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
