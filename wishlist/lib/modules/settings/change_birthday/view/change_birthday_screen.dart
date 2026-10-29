import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/current_user_birthday_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/birthday.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/utils/app_snackbar.dart';
import 'package:wishlist/shared/widgets/birthday_picker.dart';
import 'package:wishlist/shared/widgets/error_page_with_back.dart';
import 'package:wishlist/shared/widgets/page_layout.dart';

class ChangeBirthdayScreen extends ConsumerStatefulWidget {
  const ChangeBirthdayScreen({super.key});

  @override
  ConsumerState<ChangeBirthdayScreen> createState() =>
      _ChangeBirthdayScreenState();
}

class _ChangeBirthdayScreenState extends ConsumerState<ChangeBirthdayScreen> {
  @override
  void initState() {
    super.initState();
    // Once per failure: showing it from the error branch would stack a new
    // snackbar on every rebuild
    ref.listenManual(
      currentUserBirthdayProvider,
      (previous, next) {
        if (!mounted) {
          return;
        }
        if (next.hasError && !(previous?.hasError ?? false)) {
          showGenericError(context, error: next.error);
        }
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final birthday = ref.watch(currentUserBirthdayProvider);

    return birthday.when(
      loading: () => Scaffold(
        body: PageLayout(
          title: l10n.changeBirthdayScreenTitle,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stackTrace) => ErrorPageWithBack.failure(
        error: error,
        onRetry: () => ref.refresh(currentUserBirthdayProvider.future),
        isRetrying: birthday.isLoading,
      ),
      data: (birthday) => Scaffold(
        body: PageLayout(
          title: l10n.changeBirthdayScreenTitle,
          child: _ChangeBirthdayForm(birthday: birthday),
        ),
      ),
    );
  }
}

class _ChangeBirthdayForm extends ConsumerStatefulWidget {
  const _ChangeBirthdayForm({required this.birthday});

  /// Null when the user did not set one yet.
  final Birthday? birthday;

  @override
  ConsumerState<_ChangeBirthdayForm> createState() =>
      _ChangeBirthdayFormState();
}

class _ChangeBirthdayFormState extends ConsumerState<_ChangeBirthdayForm> {
  static const _defaultBirthday = Birthday(month: 1, day: 1);

  late Birthday _selected = widget.birthday ?? _defaultBirthday;

  /// Without a saved birthday, the wheels start on a default the user did not
  /// choose: saving it as is would store a wrong date.
  late bool _hasPicked = widget.birthday != null;

  /// Read once: the provider reloads after a save or a removal, possibly while
  /// the page is leaving, and the Delete button must not change in it.
  late final bool _hadBirthday = widget.birthday != null;

  bool _isSaving = false;
  bool _isRemoving = false;

  bool get _isBusy => _isSaving || _isRemoving;

  void _onSuccess(String message) {
    // The callers checked `mounted`
    // The container outlives this State: the edit profile line shows the new
    // value
    final container = ProviderScope.containerOf(context);
    showAppSnackBar(
      context,
      message,
      type: SnackBarType.success,
    );
    context.pop();
    container.invalidate(currentUserBirthdayProvider);
  }

  void _onError(AppException appException) {
    if (mounted) {
      setState(() {
        _isSaving = false;
        _isRemoving = false;
      });
      showGenericError(context, error: appException);
    }
  }

  Future<void> _onSave() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(userServiceProvider).upsertCurrentUserBirthday(_selected);

      if (mounted) {
        _onSuccess(context.l10n.changeBirthdaySuccess);
      }
    } on AppException catch (appException) {
      _onError(appException);
    }
  }

  Future<void> _onRemove() async {
    setState(() {
      _isRemoving = true;
    });

    try {
      await ref.read(userServiceProvider).deleteCurrentUserBirthday();

      if (mounted) {
        _onSuccess(context.l10n.changeBirthdayRemoved);
      }
    } on AppException catch (appException) {
      _onError(appException);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(16),
        Text(
          l10n.changeBirthdayExplanation,
          style: AppTextStyles.smaller,
        ),
        const Gap(16),
        BirthdayPicker(
          initialValue: _selected,
          onChanged: (value) {
            _selected = value;
            if (!_hasPicked) {
              setState(() => _hasPicked = true);
            }
          },
        ),
        const Gap(32),
        PrimaryButton(
          text: l10n.changeBirthdayConfirm,
          onPressed: _isBusy || !_hasPicked ? null : _onSave,
          isLoading: _isSaving,
          style: BaseButtonStyle.large,
        ),
        if (_hadBirthday) ...[
          const Gap(16),
          SecondaryButton(
            text: l10n.changeBirthdayRemove,
            onPressed: _isBusy ? null : _onRemove,
            isLoading: _isRemoving,
            style: BaseButtonStyle.large,
          ),
        ],
      ],
    );
  }
}
