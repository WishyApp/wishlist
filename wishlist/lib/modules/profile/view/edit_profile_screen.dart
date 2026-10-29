import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/infra/current_user_birthday_provider.dart';
import 'package:wishlist/shared/infra/repositories/user/user_streams_providers.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/widgets/avatar/editable_avatar.dart';
import 'package:wishlist/shared/widgets/page_layout.dart';
import 'package:wishlist/shared/widgets/settings_line.dart';
import 'package:wishlist/shared/widgets/settings_section.dart';

class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(watchCurrentUserProfileProvider);
    final birthday = ref.watch(currentUserBirthdayProvider);
    final locale = Localizations.localeOf(context).toString();

    return PageLayout.scrolling(
      title: l10n.editProfileScreenTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(8),
          const Center(child: EditableAvatar()),
          const Gap(24),
          SettingsSection(
            children: [
              SettingsLine(
                title: l10n.editProfilePseudo,
                // Nothing while loading, a dash on error: the screen behind
                // the line handles the failure.
                value: profile.whenOrNull(
                  data: (profile) => profile?.pseudo,
                  error: (error, stackTrace) => '—',
                ),
                onTap: () {
                  ChangePseudoRoute().push(context);
                },
              ),
              SettingsLine(
                title: l10n.editProfileBirthday,
                value: birthday.whenOrNull(
                  data: (birthday) =>
                      birthday?.format(locale) ??
                      l10n.editProfileBirthdayNotSet,
                  error: (error, stackTrace) => '—',
                ),
                onTap: () {
                  ChangeBirthdayRoute().push(context);
                },
              ),
            ],
          ),
          const Gap(8),
          Text(
            l10n.editProfilePrivacy,
            style: AppTextStyles.smaller.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
