import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/app/navigation/app_redirect.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/auth/view/widgets/auth_illustration.dart';
import 'package:wishlist/modules/auth/view/widgets/signup_step_layout.dart';
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
    // The route hands over the raw query parameter
    final redirectTo = sanitizeRedirectTarget(widget.redirectTo);

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
        // The settings line shows the new value. The button keeps its loading
        // state until the screen is left.
        ref.invalidate(currentUserBirthdayProvider);
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
    // Back behaves like "later": popping would land on home and lose redirectTo
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isSaving) {
          _goNext();
        }
      },
      child: SignupStepLayout(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthIllustration(asset: Assets.svg.birthday),
            const Gap(16),
            Text(
              l10n.birthdayStepTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleSmall,
            ),
            const Gap(8),
            Text(
              l10n.birthdayStepExplanation,
              textAlign: TextAlign.center,
              style: AppTextStyles.smaller.copyWith(color: AppColors.makara),
            ),
            const Gap(16),
            BirthdayPicker(
              initialValue: _selected,
              onChanged: (value) => _selected = value,
            ),
          ],
        ),
        primaryAction: PrimaryButton(
          text: l10n.changeBirthdayConfirm,
          onPressed: _isSaving ? null : _onSave,
          isLoading: _isSaving,
          style: BaseButtonStyle.large,
        ),
        secondaryAction: TextButton(
          onPressed: _isSaving ? null : _goNext,
          child: Text(
            l10n.birthdayStepLater,
            style: AppTextStyles.small.copyWith(color: AppColors.makara),
          ),
        ),
      ),
    );
  }
}
