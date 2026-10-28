import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/gen/fonts.gen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/auth/view/auth_layout.dart';
import 'package:wishlist/modules/auth/view/widgets/social_sign_in_buttons.dart';
import 'package:wishlist/shared/infra/auth_service.dart';
import 'package:wishlist/shared/infra/first_launch_service.dart';
import 'package:wishlist/shared/infra/social_sign_in_client.dart';
import 'package:wishlist/shared/infra/utils/network_error.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/utils/app_snackbar.dart';
import 'package:wishlist/shared/widgets/text_form_fields/input_email.dart';
import 'package:wishlist/shared/widgets/text_form_fields/input_password.dart';
import 'package:wishlist/shared/widgets/text_form_fields/input_pseudo_or_email.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.redirectTo,
  });

  final String? redirectTo;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pseudoOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  bool _isSocialSignInInProgress = false;

  /// Whether the user is signing in or signing up
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeSigningInState();
      }
    });
  }

  Future<void> _initializeSigningInState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firstLaunchService = FirstLaunchService(prefs);
      final isFirstLaunch = firstLaunchService.isFirstLaunch();

      if (mounted) {
        setState(() {
          _isSigningIn = !isFirstLaunch;
        });

        await firstLaunchService.markAsLaunched();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pseudoOrEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void onSuccess() {
    final redirectTo = widget.redirectTo;

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (_isSigningIn) {
        if (redirectTo != null && redirectTo.startsWith('/')) {
          context.go(redirectTo);
        } else {
          HomeRoute().go(context);
        }
      } else {
        if (redirectTo != null && redirectTo.startsWith('/')) {
          context.go(
            Uri(
              path: PseudoRoute().location,
              queryParameters: {
                'redirectTo': redirectTo,
              },
            ).toString(),
          );
        } else {
          PseudoRoute().go(context);
        }
      }
    }
  }

  void onError(AuthException authException) {
    final l10n = context.l10n;

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      final statusCode = authException.statusCode;
      if (authException is AuthWeakPasswordException) {
        showAppSnackBar(
          context,
          l10n.passwordTooWeak,
          type: SnackBarType.error,
        );
      } else if (statusCode != null) {
        switch (int.parse(statusCode)) {
          case 422:
            showAppSnackBar(
              context,
              l10n.userAlreadyRegistered,
              type: SnackBarType.error,
            );
          case 400:
            showAppSnackBar(
              context,
              l10n.invalidLoginCredentials,
              type: SnackBarType.error,
            );
          case 404:
            showAppSnackBar(
              context,
              l10n.invalidLoginCredentials,
              type: SnackBarType.error,
            );
        }
      } else {
        showGenericError(context);
      }
    }
  }

  Future<void> onPressed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      if (_isSigningIn) {
        await ref.read(authServiceProvider).signIn(
              identifier: _pseudoOrEmailController.text.trim(),
              password: _passwordController.text,
            );
      } else {
        await ref.read(authServiceProvider).signUp(
              email: _pseudoOrEmailController.text.trim(),
              password: _passwordController.text,
            );
      }

      if (mounted) {
        onSuccess();
      }
    } on AuthException catch (authException) {
      onError(authException);
    }
  }

  /// Runs a Google or Apple sign-in. There is nothing to navigate to on
  /// success: the router redirects on the new session, to the pseudo screen
  /// for a new account.
  Future<void> _signInWith(Future<bool> Function() signIn) async {
    setState(() {
      _isSocialSignInInProgress = true;
    });
    try {
      await signIn();
    } catch (e, stackTrace) {
      // Mostly a misconfigured provider or client ID: worth seeing in Sentry,
      // unlike a lost connection or a sheet the user closed.
      if (!isNetworkError(e) && !SocialSignInClient.isUserSideFailure(e)) {
        unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      }
      if (mounted) {
        showGenericError(context, error: e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSocialSignInInProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showGoogle = ref.watch(googleSignInConfigProvider) != null;
    final authService = ref.read(authServiceProvider);
    // The links would leave the screen while a sheet is open: the session
    // that comes back would then redirect from another screen.
    final areLinksEnabled = !_isSocialSignInInProgress;

    final emailOrPseudoInput = _isSigningIn
        ? InputPseudoOrEmail(
            controller: _pseudoOrEmailController,
          )
        : InputEmail(controller: _pseudoOrEmailController);

    return AuthLayout(
      formKey: _formKey,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Same footer in both modes: sign-up is the first screen shown, and
          // someone reinstalling the app looks for this link there too.
          TextButton(
            onPressed: areLinksEnabled
                ? () => ForgotPasswordRoute().push(context)
                : null,
            child: Text(
              l10n.forgotPasswordButton,
              style: AppTextStyles.smaller.copyWith(
                decoration: TextDecoration.underline,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          TextButton(
            onPressed: areLinksEnabled
                ? () {
                    setState(() {
                      _isSigningIn = !_isSigningIn;
                    });
                  }
                : null,
            child: Text(
              _isSigningIn ? l10n.dontHaveAccount : l10n.haveAccount,
              style: AppTextStyles.smaller.copyWith(
                fontFamily: FontFamily.plusJakartaSans,
                color: Colors.black,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          emailOrPseudoInput,
          const Gap(16),
          InputPassword(
            autofillHints: _isSigningIn
                ? AutofillHints.password
                : AutofillHints.newPassword,
            controller: _passwordController,
            label: l10n.passwordField,
            textInputAction: TextInputAction.done,
            showStrengthIndicator: !_isSigningIn,
            deferStrengthIndicator: true,
          ),
          const Gap(32),
          PrimaryButton(
            text: _isSigningIn ? l10n.signIn : l10n.signUp,
            onPressed: _isSocialSignInInProgress ? null : onPressed,
            isLoading: _isLoading,
            style: BaseButtonStyle.large,
          ),
          SocialSignInButtons(
            showGoogle: showGoogle,
            isEnabled: !_isLoading && !_isSocialSignInInProgress,
            onGooglePressed: () => _signInWith(authService.signInWithGoogle),
            onApplePressed: () => _signInWith(authService.signInWithApple),
          ),
        ],
      ),
    );
  }
}
