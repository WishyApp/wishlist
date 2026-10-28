import 'package:flutter/material.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/widgets/password_strength_indicator.dart';
import 'package:wishlist/shared/widgets/text_form_fields/validators/password_validator.dart';

class InputPassword extends StatefulWidget {
  const InputPassword({
    super.key,
    required this.autofillHints,
    required this.controller,
    required this.label,
    required this.textInputAction,
    this.additionalValidator,
    this.showStrengthIndicator = false,
    this.deferStrengthIndicator = false,
  });

  final String autofillHints;
  final TextEditingController controller;
  final String label;
  final TextInputAction textInputAction;
  final String? Function(String?)? additionalValidator;
  final bool showStrengthIndicator;

  /// Shows the strength indicator only once the field is focused or filled,
  /// to save room on a screen that has more to show before.
  final bool deferStrengthIndicator;

  @override
  State<InputPassword> createState() => _InputPasswordState();
}

class _InputPasswordState extends State<InputPassword> {
  bool _obscureText = true;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isStrengthIndicatorVisible =>
      widget.showStrengthIndicator &&
      (!widget.deferStrengthIndicator ||
          _focusNode.hasFocus ||
          widget.controller.text.isNotEmpty);

  void _toggleObscureText() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    final additionalValidator = widget.additionalValidator;
    final l10n = context.l10n;

    final textField = TextFormField(
      focusNode: _focusNode,
      autofillHints: [widget.autofillHints],
      textInputAction: widget.textInputAction,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return l10n.notNullError;
        }
        if (widget.showStrengthIndicator) {
          final securityError = passwordSecurityValidator(value, l10n);
          if (securityError != null) {
            return securityError;
          }
        }
        if (additionalValidator != null) {
          return additionalValidator(value);
        }
        return null;
      },
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock),
        label: Text(widget.label),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: _toggleObscureText,
        ),
        errorMaxLines: 2,
      ),
      controller: widget.controller,
      obscureText: _obscureText,
      // The password is sent exactly as typed: once revealed, the keyboard
      // must not autocorrect it, add a space after a suggestion or turn
      // quotes and dashes into typographic ones.
      autocorrect: false,
      enableSuggestions: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        textField,
        // Recomputed on every focus or text change: nothing cached, so it
        // can't go stale when the parent changes the parameters.
        ListenableBuilder(
          listenable: Listenable.merge([_focusNode, widget.controller]),
          builder: (context, _) => AnimatedSwitcher(
            duration: kThemeAnimationDuration,
            switchInCurve: Curves.fastOutSlowIn,
            switchOutCurve: Curves.fastOutSlowIn,
            transitionBuilder: (child, animation) {
              return SizeTransition(
                sizeFactor: animation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: _isStrengthIndicatorVisible
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: PasswordStrengthIndicator(
                      controller: widget.controller,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
