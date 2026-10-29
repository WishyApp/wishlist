import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/infra/repositories/user/user_streams_providers.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/widgets/avatar/app_avatar.dart';

/// Top of the home screen: photo, pseudo, a button to edit the profile and the
/// settings cog.
class HomeProfileHeader extends ConsumerWidget {
  const HomeProfileHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Default avatar and empty pseudo while loading or on error: the header
    // never blocks the screen behind it.
    final profile = ref.watch(watchCurrentUserProfileProvider).valueOrNull;

    void openEditProfile() => EditProfileRoute().push(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 8, 20),
      child: Row(
        children: [
          // Hidden from semantics: the "Edit profile" button below does the
          // same, a screen reader would announce it twice.
          ExcludeSemantics(
            child: GestureDetector(
              onTap: openEditProfile,
              child: AppAvatar(avatarUrl: profile?.avatarUrl, size: 64),
            ),
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.pseudo ?? '',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.darkGrey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                _EditProfileButton(onTap: openEditProfile),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.settingsScreenTitle,
            icon: const Icon(
              Icons.settings,
              color: AppColors.darkGrey,
              size: 28,
            ),
            onPressed: () => SettingsRoute().push(context),
          ),
        ],
      ),
    );
  }
}

/// Small outlined button. No outlined button exists in `buttons.dart`, so it
/// stays local to the header.
class _EditProfileButton extends StatelessWidget {
  const _EditProfileButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The pill keeps its look; the tap area around it is 44 px tall.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            shape: const StadiumBorder(
              side: BorderSide(color: AppColors.pastelGray),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.edit,
                      size: 14,
                      color: AppColors.darkGrey,
                    ),
                    const Gap(6),
                    Flexible(
                      child: Text(
                        context.l10n.editProfileScreenTitle,
                        style: AppTextStyles.smaller.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkGrey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
