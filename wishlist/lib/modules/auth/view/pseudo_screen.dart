import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wishlist/gen/assets.gen.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/modules/auth/view/widgets/signup_step_layout.dart';
import 'package:wishlist/shared/infra/app_exception.dart';
import 'package:wishlist/shared/infra/non_null_extensions/go_true_client_non_null_getter_user_extension.dart';
import 'package:wishlist/shared/infra/supabase_client_provider.dart';
import 'package:wishlist/shared/infra/user_service.dart';
import 'package:wishlist/shared/models/profile.dart';
import 'package:wishlist/shared/navigation/pseudo_creation_marker.dart';
import 'package:wishlist/shared/navigation/redirect_target.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/widgets/buttons.dart';
import 'package:wishlist/shared/utils/app_snackbar.dart';
import 'package:wishlist/shared/widgets/text_form_fields/validators/pseudo_validator.dart';

class PseudoScreen extends ConsumerStatefulWidget {
  const PseudoScreen({
    super.key,
    this.redirectTo,
  });

  final String? redirectTo;

  @override
  ConsumerState<PseudoScreen> createState() => _PseudoScreenState();
}

class _PseudoScreenState extends ConsumerState<PseudoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pseudoController = TextEditingController();
  bool _isLoading = false;

  void onSuccess() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      // Normally the router redirect gets there first (creating the profile
      // refreshes the session, and consumes the marker): this is the fallback,
      // skipped when that redirect already left this route. The optional step
      // carries the deep link the user came from.
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        pseudoCreationMarker.clear();
        context.go(
          locationWithRedirectTo(
            BirthdayStepRoute().location,
            sanitizeRedirectTarget(widget.redirectTo),
          ),
        );
      }
    }
  }

  void onError(AppException appException) {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      showGenericError(context, error: appException);
    }
  }

  Future<void> onPressed() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Read by the router redirect, which runs when the session is refreshed
      pseudoCreationMarker.mark();

      try {
        await ref.read(userServiceProvider).createUserProfile(
              Profile(
                id: ref.read(supabaseClientProvider).auth.currentUserNonNull.id,
                pseudo: _pseudoController.text,
              ),
            );

        onSuccess();
      } on AppException catch (appException) {
        pseudoCreationMarker.clear();
        onError(appException);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Same frame as the birthday step that follows, without the app title of
    // the sign-in screen
    return SignupStepLayout(
      illustration: Assets.svg.pseudo,
      title: l10n.pseudoStepTitle,
      explanation: l10n.pseudoStepExplanation,
      input: Form(
        key: _formKey,
        child: TextFormField(
          controller: _pseudoController,
          // The only action of the step: the keyboard comes up right away
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.pseudoField,
          ),
          textCapitalization: TextCapitalization.sentences,
          validator: (value) => pseudoValidator(value, l10n),
        ),
      ),
      primaryAction: PrimaryButton(
        onPressed: onPressed,
        text: l10n.savePseudo,
        style: BaseButtonStyle.large,
        isLoading: _isLoading,
      ),
    );
  }
}
