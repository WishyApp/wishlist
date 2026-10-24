import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/auth/view/widgets/signup_step_layout.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/utils/app_snackbar.dart';
import 'package:wishlist/shared/widgets/birthday_picker.dart';

/// Optional step of the signup, right after the pseudo: the user can give
/// their birthday or skip it. Never forced: only a pseudo just created leads
/// here, and "later" is always available.
class BirthdayStepScreen extends ConsumerStatefulWidget {
  const BirthdayStepScreen({
    super.key,
    this.redirectTo,
  });

  /// The deep link the user came from, opened once the step is done. Already
  /// sanitized by the route.
  final String? redirectTo;

  @override
  ConsumerState<BirthdayStepScreen> createState() => _BirthdayStepScreenState();
}

class _BirthdayStepScreenState extends ConsumerState<BirthdayStepScreen> {
  static const _defaultBirthday = Birthday(month: 1, day: 1);

  Birthday _selected = _defaultBirthday;
  bool _isSaving = false;

  /// The wheels start on a default the user did not choose: saving it as is
  /// would store a wrong date. "Later" is the way out for who gives nothing.
  bool _hasPicked = false;

  void _goNext() {
    final redirectTo = widget.redirectTo;

    if (redirectTo != null) {
      context.go(redirectTo);
    } else {
      HomeRoute().go(context);
    }
  }

  Future<void> _onSave() async {
    final userService = ref.read(userServiceProvider);
    setState(() {
      _isSaving = true;
    });

    try {
      await userService.upsertCurrentUserBirthday(_selected);

      if (mounted) {
        // The button keeps its loading state until the screen is left
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
    // Android back behaves like "later" (also during a save, so the step never
    // traps the user): popping would land on home and lose redirectTo. A
    // non-poppable route disables the iOS edge swipe, which does nothing here.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _goNext();
        }
      },
      child: SignupStepLayout(
        illustration: Assets.svg.birthday,
        title: l10n.birthdayStepTitle,
        explanation: l10n.birthdayStepExplanation,
        input: BirthdayPicker(
          initialValue: _selected,
          onChanged: (value) {
            _selected = value;
            if (!_hasPicked) {
              setState(() => _hasPicked = true);
            }
          },
        ),
        primaryAction: PrimaryButton(
          text: l10n.changeBirthdayConfirm,
          onPressed: _isSaving || !_hasPicked ? null : _onSave,
          isLoading: _isSaving,
          style: BaseButtonStyle.large,
        ),
        secondaryAction: TextButton(
          // Enabled during a save too: it may never answer
          onPressed: _goNext,
          child: Text(
            l10n.birthdayStepLater,
            style: AppTextStyles.small.copyWith(color: AppColors.makara),
          ),
        ),
      ),
    );
  }
}
