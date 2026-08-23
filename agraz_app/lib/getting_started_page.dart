import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'l10n/app_l10n.dart';

class GettingStartedPage extends StatelessWidget {
  const GettingStartedPage({super.key});

  static final List<_Step> _steps = [
    _Step(
      Icons.person_add_alt_1_rounded,
      'Create your account',
      'Sign up and set up your farm profile so AgRaz can tailor insights to your needs.',
    ),
    _Step(
      Icons.badge_rounded,
      'Complete your profile',
      'Add your name, location and farm details so records and reports stay accurate.',
    ),
    _Step(
      Icons.group_add_rounded,
      'Add family & members',
      'Invite family members and assign roles to manage the farm together.',
    ),
    _Step(
      Icons.account_balance_wallet_rounded,
      'Track income & expense',
      'Record every transaction to keep a clear picture of your farm finances.',
    ),
    _Step(
      Icons.agriculture_rounded,
      'Manage daily operations',
      'Log dairy, labour, documents and events in one organized place.',
    ),
    _Step(
      Icons.insights_rounded,
      'Explore insights',
      'Use weather, market prices, learning and future plans to make smart decisions.',
    ),
  ];

  static final List<_FeatureGroup> _groups = [
    _FeatureGroup(
      'Finance & Records',
      Icons.account_balance_wallet_rounded,
      AppColors.income,
      [
        _Feature(
          Icons.account_balance_wallet_rounded,
          'Income & Expense',
          AppColors.income,
          'Open from the menu, tap +, choose Income or Expense, enter amount, category and date, then save. Review totals and charts on the dashboard.',
        ),
        _Feature(
          Icons.business_rounded,
          'Manage Organization',
          AppColors.primaryLight,
          'Add your farm or organization, manage members and roles so your team can collaborate and share records.',
        ),
        _Feature(
          Icons.folder_rounded,
          'Documents',
          AppColors.accent,
          'Tap Add Document to upload and organize farm papers, schemes and certificates. Access them anytime, even offline.',
        ),
        _Feature(
          Icons.map_outlined,
          'RTC Entry',
          AppColors.primaryDark,
          'Record land and RTC (property) details to keep your land records organized and easy to reference.',
        ),
      ],
    ),
    _FeatureGroup(
      'Farm Operations',
      Icons.agriculture_rounded,
      AppColors.primary,
      [
        _Feature(
          Icons.water_drop_rounded,
          'Dairy',
          AppColors.info,
          'Log daily milk collection, fat, rate and payments. Track supplier and buyer accounts in one place.',
        ),
        _Feature(
          Icons.local_drink_rounded,
          'Dairy Owner',
          AppColors.primaryLight,
          'Manage your dairy business, suppliers and deliveries with consolidated reports and balances.',
        ),
        _Feature(
          Icons.engineering_rounded,
          'Labour Management',
          AppColors.warning,
          'Add workers, track attendance and manage labour profiles for your farm.',
        ),
        _Feature(
          Icons.handshake_rounded,
          'Labour Work Entry',
          AppColors.primaryLight,
          'Record daily labour work, tasks and wages so payments stay accurate and transparent.',
        ),
        _Feature(
          Icons.sticky_note_2_outlined,
          'Notes',
          AppColors.accent,
          'Create quick notes and reminders for anything you need to remember on the farm.',
        ),
        _Feature(
          Icons.flag_outlined,
          'Future Plans',
          AppColors.info,
          'Plan crops, activities and goals ahead, and track their progress over time.',
        ),
        _Feature(
          Icons.event_available_rounded,
          'Event Manage',
          AppColors.warning,
          'Schedule farm events, reminders and activities so nothing important is missed.',
        ),
      ],
    ),
    _FeatureGroup(
      'Market & Advisory',
      Icons.trending_up_rounded,
      AppColors.info,
      [
        _Feature(
          Icons.trending_up_rounded,
          'Market Reports',
          AppColors.info,
          'Check live market prices and trends to decide the best time to buy or sell.',
        ),
        _Feature(
          Icons.cloud_outlined,
          'Weather Report',
          AppColors.info,
          'View current weather and forecasts to plan farm activities safely.',
        ),
        _Feature(
          Icons.store_rounded,
          'Buy & Sell',
          AppColors.primaryLight,
          'Browse the marketplace to buy products or list your own produce for sale.',
        ),
        _Feature(
          Icons.miscellaneous_services_rounded,
          'General Services',
          AppColors.expense,
          'Find local agricultural services like equipment, repair and farm support near you.',
        ),
      ],
    ),
    _FeatureGroup(
      'Learning & Support',
      Icons.menu_book_rounded,
      AppColors.accent,
      [
        _Feature(
          Icons.menu_book_rounded,
          'Farmer Education',
          AppColors.accent,
          'Read articles and guides to learn better and more profitable farming practices.',
        ),
        _Feature(
          Icons.account_balance_rounded,
          'Government Facilities',
          AppColors.info,
          'Discover loans, insurance and government schemes you may be eligible for.',
        ),
        _Feature(
          Icons.feedback_outlined,
          'Feedback',
          AppColors.accent,
          'Share your suggestions or report issues from the Help Center or any screen to help us improve AgRaz.',
        ),
      ],
    ),
    _FeatureGroup(
      'Your Account',
      Icons.person_rounded,
      AppColors.info,
      [
        _Feature(
          Icons.person_rounded,
          'Profile',
          AppColors.info,
          'Update your personal details, language and preferences from the account menu.',
        ),
        _Feature(
          Icons.family_restroom,
          'Family members',
          AppColors.primary,
          'Invite family members and assign roles to manage the farm together under one account.',
        ),
        _Feature(
          Icons.settings_rounded,
          'Settings',
          AppColors.textSecondary,
          'Adjust app settings such as language, notifications and appearance.',
        ),
        _Feature(
          Icons.groups_rounded,
          'About Team',
          AppColors.primaryLight,
          'Meet the people behind AgRaz and learn about our mission.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: tr('Getting Started')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Welcome to AgRaz'), style: AppText.h2),
            const SizedBox(height: 6),
            Text(
              tr('Follow these simple steps to get the most out of the app.'),
              style: AppText.small,
            ),
            const SizedBox(height: 18),
            ..._steps.map((s) => _buildStep(s)).toList(),
            const SizedBox(height: 22),
            _sectionTitle(tr('Explore features & modules')),
            const SizedBox(height: 4),
            Text(
              tr('Here is how to use every module available in AgRaz.'),
              style: AppText.small,
            ),
            const SizedBox(height: 14),
            ..._groups.map((g) => _buildGroup(g)).toList(),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const TintedIcon(
                    icon: Icons.help_rounded,
                    color: AppColors.primary,
                    boxSize: 44,
                    size: 22,
                    radius: 14,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('Need help along the way? Open the Help Center anytime from the menu.'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppText.h3),
      ],
    );
  }

  Widget _buildStep(_Step step) {
    final index = _steps.indexOf(step) + 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primarySoft, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintedIcon(
            icon: step.icon,
            color: AppColors.primary,
            boxSize: 46,
            size: 22,
            radius: 14,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$index',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(step.title),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(tr(step.description), style: AppText.small),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(_FeatureGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primarySoft, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: group.color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                TintedIcon(
                  icon: group.icon,
                  color: group.color,
                  boxSize: 38,
                  size: 20,
                  radius: 12,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr(group.title),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: group.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: group.features
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildFeature(f),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(_Feature feature) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TintedIcon(
          icon: feature.icon,
          color: feature.color,
          boxSize: 40,
          size: 20,
          radius: 12,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(feature.title),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(tr(feature.howTo), style: AppText.small),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step {
  final IconData icon;
  final String title;
  final String description;
  const _Step(this.icon, this.title, this.description);
}

class _Feature {
  final IconData icon;
  final String title;
  final Color color;
  final String howTo;
  const _Feature(this.icon, this.title, this.color, this.howTo);
}

class _FeatureGroup {
  final String title;
  final IconData icon;
  final Color color;
  final List<_Feature> features;
  const _FeatureGroup(this.title, this.icon, this.color, this.features);
}
