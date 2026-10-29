import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:wishlist/l10n/l10n.dart';
import 'package:wishlist/shared/infra/repositories/user/user_streams_providers.dart';
import 'package:wishlist/shared/navigation/routes.dart';
import 'package:wishlist/shared/theme/colors.dart';
import 'package:wishlist/shared/theme/text_styles.dart';
import 'package:wishlist/shared/theme/widgets/app_app_bar.dart';
import 'package:wishlist/shared/widgets/avatar/app_avatar.dart';

/// Top of the home screen: photo, pseudo, a button to edit the profile and the
/// settings cog.
class HomeProfileHeader extends ConsumerWidget {
  const HomeProfileHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Default avatar and empty pseudo while loading or on error: the header
    // never blocks the screen behind it.
    final profile = ref.watch(watchCurrentUserProfileProvider).valueOrNull;

    void openEditProfile() => EditProfileRoute().push(context);

    return Stack(
      children: [
        Padding(
          // Close to the title of the other tabs' AppAppBar, a bit lower
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
          child: Row(
            children: [
              // Hidden from semantics: the "Edit profile" button below does the
              // same, a screen reader would announce it twice.
              ExcludeSemantics(
                child: Stack(
                  children: [
                    AppAvatar(avatarUrl: profile?.avatarUrl, size: 64),
                    // Above the photo, which is opaque: the ripple shows on it
                    Positioned.fill(
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: openEditProfile,
                          customBorder: const CircleBorder(),
                        ),
                      ),
                    ),
                  ],
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
              // Room for the settings cog laid over the row
              const Gap(52),
            ],
          ),
        ),
        // Same size and place as the cog of the other tabs' AppAppBar:
        // centred in a toolbar-high band, 12 from the right edge.
        const Positioned(
          top: (kToolbarHeight - kMinInteractiveDimension) / 2,
          right: 12,
          child: SettingsButton(),
        ),
      ],
    );
  }
}

/// Small outlined button. No outlined button exists in `buttons.dart`, so it
/// stays local to the header.
@visibleForTesting
const editProfilePillKey = ValueKey('edit-profile-pill');

class _EditProfileButton extends StatelessWidget {
  const _EditProfileButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The pill stays at its own size, centred in a 44 px tall hit area as wide
    // as the pill. The ink (ripple and highlight) is clipped to the pill by its
    // own Material, so it matches what is seen. A tap on the pill is taken by
    // the InkWell, a tap on the strip above or below it by the GestureDetector:
    // never both, so `onTap` runs once.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Center(
          widthFactor: 1,
          child: Material(
            key: editProfilePillKey,
            type: MaterialType.transparency,
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
                    const Icon(Icons.edit, size: 14, color: AppColors.darkGrey),
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
