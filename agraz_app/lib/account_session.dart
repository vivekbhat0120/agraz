import 'package:flutter/foundation.dart';

/// Toggleable home-menu options. Empty [disabledFeatures] means every option
/// is available (the default for family sub-members).
class AppFeatureCatalog {
  static const incomeExpense = 'income_expense';
  static const organization = 'organization';
  static const labour = 'labour';
  static const labourWork = 'labour_work';
  static const dairy = 'dairy';
  static const dairyOwner = 'dairy_owner';
  static const notes = 'notes';
  static const dailySummary = 'daily_summary';
  static const futurePlans = 'future_plans';
  static const market = 'market';
  static const weather = 'weather';
  static const services = 'services';
  static const buySell = 'buy_sell';
  static const farmerEducation = 'farmer_education';
  static const achieversLobby = 'achievers_lobby';
  static const government = 'government';
  static const rtc = 'rtc';
  static const documents = 'documents';
  static const eventManage = 'event_manage';
  static const feedback = 'feedback';
  static const profile = 'profile';
  static const settings = 'settings';

  static const List<({String key, String label})> all = [
    (key: incomeExpense, label: 'Income & Expense'),
    (key: organization, label: 'Manage Organization'),
    (key: labour, label: 'Labour Management'),
    (key: labourWork, label: 'Labour Work Entry'),
    (key: dairy, label: 'Dairy'),
    (key: dairyOwner, label: 'Dairy Owner'),
    (key: notes, label: 'Notes'),
    (key: dailySummary, label: 'Daily Summary'),
    (key: futurePlans, label: 'Future Plans'),
    (key: market, label: 'Market Reports'),
    (key: weather, label: 'Weather Report'),
    (key: services, label: 'General Services'),
    (key: buySell, label: 'Buy & Sell'),
    (key: farmerEducation, label: 'Farmer Education'),
    (key: achieversLobby, label: 'Achievers Lobby'),
    (key: government, label: 'Government Facilities'),
    (key: rtc, label: 'RTC Entry'),
    (key: documents, label: 'Documents'),
    (key: eventManage, label: 'Event Manage'),
    (key: feedback, label: 'Feedback'),
    (key: profile, label: 'Profile'),
    (key: settings, label: 'Settings'),
  ];
}

class AccountSession {
  final bool isSubUser;
  final bool canManageFamily;
  final List<String> disabledFeatures;
  final String accountName;
  final String? memberName;
  final String? memberEmail;

  const AccountSession({
    required this.isSubUser,
    required this.canManageFamily,
    required this.disabledFeatures,
    required this.accountName,
    this.memberName,
    this.memberEmail,
  });

  static const guest = AccountSession(
    isSubUser: false,
    canManageFamily: false,
    disabledFeatures: [],
    accountName: '',
  );

  bool allows(String featureKey) => !disabledFeatures.contains(featureKey);

  factory AccountSession.fromJson(Map data) {
    final isSub = data['is_sub_user'] == true;
    final first = data['firstname']?.toString() ?? '';
    final last = data['lastname']?.toString() ?? '';
    final accountName = '$first $last'.trim();
    String? memberName;
    String? memberEmail;
    final member = data['member'];
    if (member is Map) {
      final mf = member['firstname']?.toString() ?? '';
      final ml = member['lastname']?.toString() ?? '';
      memberName = '$mf $ml'.trim();
      if (memberName.isEmpty) memberName = null;
      memberEmail = member['email']?.toString();
    }
    final raw = data['disabled_features'];
    final disabled = <String>[];
    if (raw is List) {
      for (final item in raw) {
        final k = item?.toString().trim() ?? '';
        if (k.isNotEmpty) disabled.add(k);
      }
    }
    return AccountSession(
      isSubUser: isSub,
      canManageFamily: !isSub,
      disabledFeatures: disabled,
      accountName: accountName,
      memberName: memberName,
      memberEmail: memberEmail,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AccountSession &&
      isSubUser == other.isSubUser &&
      canManageFamily == other.canManageFamily &&
      accountName == other.accountName &&
      memberName == other.memberName &&
      memberEmail == other.memberEmail &&
      listEquals(disabledFeatures, other.disabledFeatures);

  @override
  int get hashCode => Object.hash(
        isSubUser,
        canManageFamily,
        accountName,
        memberName,
        memberEmail,
        Object.hashAll(disabledFeatures),
      );
}
