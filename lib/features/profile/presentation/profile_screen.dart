import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile2/app/core/providers/core_providers.dart';
import 'package:mobile2/shared/data/app_providers.dart';
import 'package:mobile2/shared/models/backend_models.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';
import 'package:mobile2/shared/widgets/dateasy_bottom_nav.dart';
import 'package:mobile2/shared/widgets/dateasy_media_viewer.dart';
import 'package:mobile2/shared/widgets/dateasy_phone_frame.dart';
import 'package:mobile2/shared/widgets/dateasy_refresh_indicator.dart';
import 'package:mobile2/shared/widgets/dateasy_remote_image.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final profileState = ref.watch(ownProfileProvider);
    final profile = profileState.valueOrNull;
    final wallet = ref.watch(tokenWalletProvider);
    final verification = ref.watch(verificationProvider).valueOrNull;
    final subscription = ref.watch(subscriptionProvider).valueOrNull;
    final hostDashboard = ref.watch(hostDashboardProvider);

    return DateasyPhoneFrame(
      child: Stack(
        children: [
          DateasyRefreshIndicator(
            onRefresh: () async {
              ref.invalidate(ownProfileProvider);
              ref.invalidate(tokenWalletProvider);
              ref.invalidate(verificationProvider);
              ref.invalidate(subscriptionProvider);
              ref.invalidate(hostDashboardProvider);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 16,
                bottom: 144,
              ),
              children: [
                _Header(userId: currentUser?.id),
                if (profileState.isLoading && profile == null)
                  const _ProfileLoadingBlock()
                else if (profileState.hasError && profile == null)
                  const _ProfileEmptyBlock(
                    text: 'Профиль не загрузился',
                  )
                else
                  _AvatarBlock(
                    profile: profile,
                    currentUser: currentUser,
                    verification: verification,
                    subscription: subscription,
                  ),
                _StatsCard(profile: profile),
                const _PremiumCard(),
                _VerificationCard(verification: verification),
                _WalletCard(wallet: wallet),
                _HostDashboardCard(
                  pendingCount:
                      hostDashboard.valueOrNull?.pendingRequestsCount ?? 0,
                ),
                const _GiveawaysCard(),
                _InterestsSection(profile: profile),
                _GallerySection(profile: profile),
                _MyMeetingsSection(hostDashboard: hostDashboard),
              ],
            ),
          ),
          const DateasyBottomNav(),
        ],
      ),
    );
  }
}

class _ProfileLoadingBlock extends StatelessWidget {
  const _ProfileLoadingBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 32, 20, 8),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ProfileEmptyBlock extends StatelessWidget {
  const _ProfileEmptyBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: _GlassPanel(
        borderRadius: 20,
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DateasyColors.muted,
              ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _GlassIconButton(
            icon: LucideIcons.share2,
            onTap: () {
              final id = userId == null || userId!.isEmpty
                  ? 'me'
                  : Uri.encodeComponent(userId!);
              context.go('/share?targetType=profile&targetId=$id');
            },
          ),
          Expanded(
            child: Text(
              'Профиль',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          _GlassIconButton(
            icon: LucideIcons.settings,
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({
    required this.profile,
    required this.currentUser,
    required this.verification,
    required this.subscription,
  });

  final BackendCardItem? profile;
  final BackendUser? currentUser;
  final VerificationStateData? verification;
  final SubscriptionStateData? subscription;

  @override
  Widget build(BuildContext context) {
    final name = _profileName(profile, currentUser);
    final age = _profileAge(profile);
    final location = _profileLocation(profile, currentUser);
    final bio = _profileBio(profile);
    final imageUrl = profile?.imageUrl ?? currentUser?.avatarUrl;
    final verified =
        verification?.status == 'verified' || _profileVerified(profile);
    final frendlyPlus = _subscriptionHasFrendlyPlus(subscription) ||
        _profileFrendlyPlus(profile);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 126,
                height: 126,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: dateasyLimeGradient,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66BEFF67),
                      blurRadius: 28,
                      spreadRadius: -10,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: DateasyColors.background,
                  ),
                  child: ClipOval(
                    child: DateasyRemoteImage(
                      imageUrl: imageUrl,
                      usage: DateasyImageUsage.avatar,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: GestureDetector(
                  onTap: () => context.push('/profile/edit'),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: DateasyColors.foreground,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: DateasyColors.background,
                        width: 4,
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.camera,
                      color: DateasyColors.backgroundDeep,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              Text(
                age == null ? name : '$name, $age',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (verified)
                const _ProfileStatusBadge(
                  label: 'Verified',
                  icon: LucideIcons.badgeCheck,
                  background: DateasyColors.surface2,
                  foreground: DateasyColors.lime,
                ),
              if (frendlyPlus)
                const _ProfileStatusBadge(
                  label: 'Frendly+',
                  icon: LucideIcons.crown,
                  background: DateasyColors.pink,
                  foreground: DateasyColors.backgroundDeep,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.mapPin,
                size: 14,
                color: DateasyColors.muted,
              ),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DateasyColors.muted,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              bio.isEmpty ? 'Добавьте описание профиля' : bio,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DateasyColors.muted,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatusBadge extends StatelessWidget {
  const _ProfileStatusBadge({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.profile});

  final BackendCardItem? profile;

  @override
  Widget build(BuildContext context) {
    final meetings = _profileNumber(profile, [
      'meetingsCount',
      'meetupCount',
      'eventsCount',
      'visitedEventsCount',
    ]);
    final matches = _profileNumber(profile, ['matchesCount', 'matchCount']);
    final rating = _profileRating(profile);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: _GlassPanel(
        borderRadius: 24,
        padding: const EdgeInsets.all(4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Row(
            children: [
              Expanded(
                child: _StatTile(
                  value: meetings ?? '0',
                  label: 'Встреч',
                  color: DateasyColors.lime,
                ),
              ),
              const _Divider(),
              Expanded(
                child: _StatTile(
                  value: matches ?? '0',
                  label: 'Мэтчей',
                  color: DateasyColors.pink,
                ),
              ),
              const _Divider(),
              Expanded(
                child: _StatTile(
                  value: rating ?? '—',
                  label: 'Рейтинг',
                  color: DateasyColors.lilac,
                  icon: Icons.star,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    this.icon,
  });

  final String value;
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: 'Sora',
                      fontSize: 26,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DateasyColors.muted,
                        fontSize: 11,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GestureDetector(
        onTap: () => context.push('/paywall'),
        child: Container(
          decoration: BoxDecoration(
            gradient: dateasyPinkGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55FF639F),
                blurRadius: 28,
                spreadRadius: -12,
                offset: Offset(0, 16),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: DateasyColors.background.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  LucideIcons.crown,
                  color: DateasyColors.foreground,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Frendly Plus',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: DateasyColors.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Безлимит свайпов, приоритет в радаре',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.foreground
                                .withValues(alpha: 0.78),
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: DateasyColors.background.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Открыть',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DateasyColors.foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.verification});

  final VerificationStateData? verification;

  @override
  Widget build(BuildContext context) {
    final status = verification?.status ?? 'not_started';
    final verified = status == 'verified';
    final waiting = status == 'under_review' || status == 'document_submitted';
    final selfieSubmitted =
        status == 'selfie_submitted' && verification?.documentDone != true;
    final title = verified
        ? 'Верификация пройдена'
        : waiting
            ? 'Проверка идёт'
            : selfieSubmitted
                ? 'Осталось добавить фото документа'
                : 'Пройти верификацию';
    final subtitle = verified
        ? 'Галочка в профиле · 3 дня Frendly+'
        : waiting
            ? 'Заявка на проверке. Пришлём уведомление'
            : selfieSubmitted
                ? 'Селфи готово · добавь фото документа'
                : 'Селфи + фото документа · 1 минута';
    final badge = verified
        ? 'готово'
        : waiting
            ? 'на проверке'
            : selfieSubmitted
                ? 'фото'
                : '+ галочка';
    final icon = verified
        ? LucideIcons.badgeCheck
        : waiting
            ? LucideIcons.clock
            : LucideIcons.badgeCheck;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GestureDetector(
        onTap: verified ? null : () => context.push('/verify'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: DateasyColors.glass,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: DateasyColors.lime.withValues(alpha: 0.3),
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          DateasyColors.lime.withValues(alpha: 0.1),
                          DateasyColors.lime2.withValues(alpha: 0.04),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: dateasyLimeGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x55BEFF67),
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          color: DateasyColors.backgroundDeep,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: DateasyColors.lime
                                        .withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    badge,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: DateasyColors.lime,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: DateasyColors.muted,
                                    fontSize: 12,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        verified ? LucideIcons.check : LucideIcons.chevronRight,
                        color:
                            verified ? DateasyColors.lime : DateasyColors.muted,
                        size: 18,
                      ),
                    ],
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

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.wallet});

  final AsyncValue<TokenWalletData> wallet;

  @override
  Widget build(BuildContext context) {
    final balance = wallet.valueOrNull?.balance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GestureDetector(
        onTap: () => context.push('/wallet'),
        child: _GlassPanel(
          borderRadius: 24,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: dateasyLimeGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  LucideIcons.wallet,
                  color: DateasyColors.backgroundDeep,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Кошелёк токенов',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      balance == null
                          ? 'Пополнение, история, бусты'
                          : '$balance FT на балансе',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.muted,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: DateasyColors.muted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HostDashboardCard extends StatelessWidget {
  const _HostDashboardCard({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GestureDetector(
        onTap: () => context.push('/host'),
        child: _GlassPanel(
          borderRadius: 24,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: DateasyColors.pink,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  LucideIcons.layoutDashboard,
                  color: DateasyColors.backgroundDeep,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Host dashboard',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Заявки, встречи и бусты',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.muted,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              if (pendingCount > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: DateasyColors.lime,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$pendingCount заявки',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: DateasyColors.backgroundDeep,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              const Icon(
                LucideIcons.chevronRight,
                color: DateasyColors.muted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GiveawaysCard extends StatelessWidget {
  const _GiveawaysCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GestureDetector(
        onTap: () => context.push('/giveaways'),
        child: _GlassPanel(
          borderRadius: 24,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: dateasyPinkGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  LucideIcons.trophy,
                  color: DateasyColors.foreground,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Розыгрыши месяца',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: DateasyColors.lime.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'авто · iPhone',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: DateasyColors.lime,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Билеты, история, победители',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DateasyColors.muted,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                LucideIcons.chevronRight,
                color: DateasyColors.muted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterestsSection extends StatelessWidget {
  const _InterestsSection({required this.profile});

  final BackendCardItem? profile;

  @override
  Widget build(BuildContext context) {
    final interests = _profileInterests(profile);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: [
          _SectionHeader(
            title: 'Интересы',
            action: 'Изменить',
            onTap: () => context.push('/profile/edit'),
          ),
          const SizedBox(height: 12),
          if (interests.isEmpty)
            _EmptyInlineState(
              text: 'Интересы не добавлены',
              onTap: () => context.push('/profile/edit'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final interest in interests)
                  _InterestPill(
                    label: interest,
                    icon: _interestIcon(interest),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InterestPill extends StatelessWidget {
  const _InterestPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      borderRadius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: DateasyColors.lime),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
          ),
        ],
      ),
    );
  }
}

class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.profile});

  final BackendCardItem? profile;

  @override
  Widget build(BuildContext context) {
    final allPhotos = _profilePhotos(profile);
    final photos = allPhotos.take(6).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: [
          _SectionHeader(
            title: 'Галерея',
            action: 'Все',
            showChevron: true,
            onTap: () => context.push('/profile/gallery'),
          ),
          const SizedBox(height: 12),
          if (photos.isEmpty)
            _EmptyInlineState(
              text: 'Фото не добавлены',
              onTap: () => context.push('/profile/edit'),
            )
          else
            GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: photos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => showDateasyMediaViewer(
                    context,
                    items: _mediaItems(allPhotos),
                    initialIndex: index,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: DateasyRemoteImage(
                        imageUrl: photos[index],
                        usage: DateasyImageUsage.card,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _MyMeetingsSection extends StatelessWidget {
  const _MyMeetingsSection({required this.hostDashboard});

  final AsyncValue<HostDashboardData> hostDashboard;

  @override
  Widget build(BuildContext context) {
    final meetings = _profileMeetingItems(
      hosted: hostDashboard.valueOrNull?.events ?? const <BackendCardItem>[],
    );
    final loading = hostDashboard.isLoading && meetings.isEmpty;
    final hasError = hostDashboard.hasError && meetings.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: [
          _SectionHeader(
            title: 'Мои встречи',
            action: 'История',
            showChevron: true,
            onTap: () => context.push('/profile/history'),
          ),
          const SizedBox(height: 12),
          if (loading)
            const _InlineLoadingState()
          else if (hasError)
            const _EmptyInlineState(text: 'Встречи не загрузились')
          else if (meetings.isEmpty)
            const _EmptyInlineState(text: 'Встреч пока нет')
          else
            for (var index = 0; index < meetings.take(2).length; index++) ...[
              _MeetingRow(meeting: meetings[index]),
              if (index != meetings.take(2).length - 1)
                const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

List<BackendCardItem> _profileMeetingItems({
  required List<BackendCardItem> hosted,
}) {
  final byId = <String, BackendCardItem>{};
  final now = DateTime.now();
  for (final meeting in hosted) {
    if (meeting.id.isEmpty) {
      continue;
    }
    if (!_isActiveProfileMeeting(meeting, now)) {
      continue;
    }
    byId.putIfAbsent(meeting.id, () => meeting);
  }
  final items = byId.values.toList(growable: false);
  items.sort((left, right) {
    final leftTime = left.startsAt;
    final rightTime = right.startsAt;
    final leftFuture = leftTime != null && !leftTime.isBefore(now);
    final rightFuture = rightTime != null && !rightTime.isBefore(now);
    if (leftFuture != rightFuture) {
      return leftFuture ? -1 : 1;
    }
    if (leftTime == null || rightTime == null) {
      return left.title.compareTo(right.title);
    }
    return leftFuture
        ? leftTime.compareTo(rightTime)
        : rightTime.compareTo(leftTime);
  });
  return items;
}

bool _isActiveProfileMeeting(BackendCardItem meeting, DateTime now) {
  final status = (meeting.raw['liveStatus'] ?? meeting.raw['status'])
      ?.toString()
      .toLowerCase()
      .trim();
  if (status == 'finished' ||
      status == 'completed' ||
      status == 'canceled' ||
      status == 'cancelled' ||
      status == 'archived') {
    return false;
  }
  final startsAt = meeting.startsAt;
  if (startsAt == null) {
    return true;
  }
  return startsAt.add(const Duration(hours: 24)).isAfter(now);
}

class _MeetingRow extends StatelessWidget {
  const _MeetingRow({required this.meeting});

  final BackendCardItem meeting;

  @override
  Widget build(BuildContext context) {
    final role = meeting.raw['role']?.toString() ??
        meeting.raw['participantRole']?.toString() ??
        '';
    final host = role == 'host' || role == 'Хост';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/meetings/${meeting.id}'),
      child: _GlassPanel(
        borderRadius: 16,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: dateasyLimeGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                host ? '★' : '→',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: DateasyColors.backgroundDeep,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _meetingSubtitle(meeting),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DateasyColors.muted,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: DateasyColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    this.showChevron = false,
    this.onTap,
  });

  final String title;
  final String action;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              Text(
                action,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DateasyColors.muted,
                    ),
              ),
              if (showChevron) ...[
                const SizedBox(width: 3),
                const Icon(
                  LucideIcons.chevronRight,
                  color: DateasyColors.muted,
                  size: 14,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      borderRadius: 16,
      padding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.borderRadius,
    required this.padding,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DateasyColors.glass,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 64,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

class _InlineLoadingState extends StatelessWidget {
  const _InlineLoadingState();

  @override
  Widget build(BuildContext context) {
    return const _GlassPanel(
      borderRadius: 16,
      padding: EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _EmptyInlineState extends StatelessWidget {
  const _EmptyInlineState({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _GlassPanel(
        borderRadius: 16,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(
              LucideIcons.circleDashed,
              size: 16,
              color: DateasyColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DateasyColors.muted,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _profileName(BackendCardItem? profile, BackendUser? currentUser) {
  final title = profile?.title.trim();
  if (title != null && title.isNotEmpty) {
    return title;
  }
  final name = currentUser?.name.trim();
  return name == null || name.isEmpty ? 'Профиль' : name;
}

int? _profileAge(BackendCardItem? profile) {
  final value = profile?.raw['age'];
  if (value is int && value > 0) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '');
}

bool _profileVerified(BackendCardItem? profile) {
  final raw = profile?.raw;
  if (raw == null) {
    return false;
  }
  return raw['verified'] == true ||
      raw['isVerified'] == true ||
      raw['verificationStatus'] == 'verified';
}

bool _profileFrendlyPlus(BackendCardItem? profile) {
  final raw = profile?.raw;
  if (raw == null) {
    return false;
  }
  final status = raw['subscriptionStatus']?.toString().toLowerCase();
  return raw['frendlyPlus'] == true ||
      raw['isFrendlyPlus'] == true ||
      raw['hasFrendlyPlus'] == true ||
      raw['premium'] == true ||
      raw['isPremium'] == true ||
      status == 'active' ||
      status == 'trial';
}

bool _subscriptionHasFrendlyPlus(SubscriptionStateData? subscription) {
  final status = subscription?.status.toLowerCase();
  return status == 'active' || status == 'trial';
}

String _profileLocation(BackendCardItem? profile, BackendUser? currentUser) {
  final city = profile?.city ?? currentUser?.city;
  final area = profile?.raw['area']?.toString().trim();
  final distance = profile?.raw['distance']?.toString().trim() ??
      profile?.raw['distanceText']?.toString().trim();
  final parts = [
    if (city != null && city.trim().isNotEmpty) city.trim(),
    if (area != null && area.isNotEmpty) area,
    if (distance != null && distance.isNotEmpty) distance,
  ];
  return parts.isEmpty ? 'Город не выбран' : parts.join(' · ');
}

String _profileBio(BackendCardItem? profile) {
  final subtitle = profile?.subtitle?.trim();
  if (subtitle != null && subtitle.isNotEmpty) {
    return subtitle;
  }
  return profile?.raw['bio']?.toString().trim() ?? '';
}

String? _profileNumber(BackendCardItem? profile, List<String> keys) {
  if (profile == null) {
    return null;
  }
  final stats = profile.raw['stats'];
  for (final key in keys) {
    final value = profile.raw[key] ?? (stats is Map ? stats[key] : null);
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) {
      return parsed.toString();
    }
  }
  return null;
}

String? _profileRating(BackendCardItem? profile) {
  if (profile == null) {
    return null;
  }
  final stats = profile.raw['stats'];
  final value = profile.raw['rating'] ??
      profile.raw['score'] ??
      (stats is Map ? stats['rating'] : null);
  final parsed = double.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed.toStringAsFixed(parsed.truncateToDouble() == parsed ? 0 : 1);
}

List<String> _profileInterests(BackendCardItem? profile) {
  final raw = profile?.raw['interests'];
  if (raw is! List) {
    return const [];
  }
  return raw
      .map((item) {
        if (item is Map) {
          return item['name'] ?? item['title'] ?? item['label'];
        }
        return item;
      })
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

List<String> _profilePhotos(BackendCardItem? profile) {
  if (profile == null) {
    return const [];
  }
  final photos = profile.raw['photos'];
  if (photos is! List) {
    final avatar = profile.imageUrl;
    return avatar == null || avatar.isEmpty ? const [] : [avatar];
  }
  final urls = photos
      .whereType<Map>()
      .map((photo) => photo['url'] ?? (photo['media'] as Map?)?['url'])
      .map((url) => url?.toString() ?? '')
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
  if (urls.isNotEmpty) {
    return urls;
  }
  final avatar = profile.imageUrl;
  return avatar == null || avatar.isEmpty ? const [] : [avatar];
}

List<DateasyMediaItem> _mediaItems(List<String> photos) {
  return photos
      .map((url) => DateasyMediaItem(imageUrl: url))
      .toList(growable: false);
}

IconData _interestIcon(String interest) {
  final value = interest.toLowerCase();
  if (value.contains('coffee') || value.contains('коф')) {
    return LucideIcons.coffee;
  }
  if (value.contains('music') || value.contains('винил')) {
    return LucideIcons.music2;
  }
  if (value.contains('art') || value.contains('галер')) {
    return LucideIcons.palette;
  }
  if (value.contains('walk') || value.contains('прогул')) {
    return LucideIcons.footprints;
  }
  return LucideIcons.sparkles;
}

String _meetingSubtitle(BackendCardItem meeting) {
  final role = meeting.raw['role']?.toString() ??
      meeting.raw['participantRole']?.toString() ??
      meeting.raw['status']?.toString();
  final date = _formatMeetingDate(meeting.startsAt);
  if (date.isNotEmpty && role != null && role.isNotEmpty) {
    return '$date · $role';
  }
  if (date.isNotEmpty) {
    return date;
  }
  return role == null || role.isEmpty ? 'Детали встречи' : role;
}

String _formatMeetingDate(DateTime? date) {
  if (date == null) {
    return '';
  }
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day.$month $hour:$minute';
}
