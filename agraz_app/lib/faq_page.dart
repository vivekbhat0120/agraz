import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'l10n/app_l10n.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  static final List<_Faq> _faqs = [
    _Faq(
      'What is AgRaz?',
      'AgRaz is a farm management app that helps you track income, expenses, dairy, labour, documents, and market insights in one place.',
    ),
    _Faq(
      'Is my data safe?',
      'Your data is stored securely and linked to your account. You can back up documents and records within the app.',
    ),
    _Faq(
      'Do I need internet to use the app?',
      'Many features work offline and sync automatically when you reconnect. Some features like weather and market prices need internet.',
    ),
    _Faq(
      'How do I add family members?',
      'Go to your profile and use the Family Members option to invite and manage people in your farm account.',
    ),
    _Faq(
      'How do I record transactions?',
      'Open Income & Expense from the menu and use the add button to record income or expense entries.',
    ),
    _Faq(
      'Can I send feedback?',
      'Yes. Open the Help Center and choose Send Feedback, or use the feedback option available on most screens.',
    ),
    _Faq(
      'How do I contact support?',
      'Open the Help Center and tap Contact Support to email our team, or call our support helpline.',
    ),
    _Faq(
      'Is AgRaz free to use?',
      'AgRaz is free to download and use for core farm management features.',
    ),
    _Faq(
      'How do I create an account?',
      'Open the app, tap Sign Up, enter your details and verify your mobile number to create your farm account.',
    ),
    _Faq(
      'I forgot my password. How do I reset it?',
      'On the login screen tap Forgot Password, enter your registered mobile or email, and follow the link to set a new password.',
    ),
    _Faq(
      'How do I add a dairy or milk entry?',
      'Open Dairy from the menu, tap the add button, enter fat, rate, quantity and supplier or buyer details, then save.',
    ),
    _Faq(
      'How do I record labour work and wages?',
      'Go to Labour Work Entry, add the worker, task, date and wage. You can also manage workers in Labour Management.',
    ),
    _Faq(
      'How do I upload and manage documents?',
      'Open Documents, tap Add Document, choose a file from your device, add a title and category, then save it safely in the app.',
    ),
    _Faq(
      'How do I change the app language?',
      'Open Settings from the account menu and choose your preferred language. The app supports English and Kannada.',
    ),
    _Faq(
      'Does my data sync across devices?',
      'Yes. When you are online, your records sync to your account so you can access them from any device after logging in.',
    ),
    _Faq(
      'How do I back up my data?',
      'Your data is linked to your account and synced automatically when online. Keep your login details safe to restore access anytime.',
    ),
    _Faq(
      'How do I check market prices and weather?',
      'Open Market Reports for live prices and Weather Report for current conditions and forecasts to plan your activities.',
    ),
    _Faq(
      'How do I add a new organization or farm?',
      'Open Manage Organization from the menu and use the add option to create a new farm or organization profile.',
    ),
    _Faq(
      'Who can see my farm data?',
      'Only you and the family members or team you invite can see your data. We never share your information without your permission.',
    ),
    _Faq(
      'How do I delete my data or account?',
      'To delete your data or account, contact our support team from the Help Center and we will assist you with the request.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: tr('FAQ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Frequently asked questions'), style: AppText.h2),
            const SizedBox(height: 6),
            Text(
              tr('Find quick answers to common questions about AgRaz.'),
              style: AppText.small,
            ),
            const SizedBox(height: 16),
            ..._faqs.map((f) => _buildFaq(context, f)),
          ],
        ),
      ),
    );
  }

  Widget _buildFaq(BuildContext context, _Faq faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primarySoft, width: 1.2),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const TintedIcon(
            icon: Icons.quiz_rounded,
            color: AppColors.accent,
            boxSize: 40,
            size: 20,
            radius: 12,
          ),
          title: Text(
            tr(faq.question),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(tr(faq.answer), style: AppText.small),
            ),
          ],
        ),
      ),
    );
  }
}

class _Faq {
  final String question;
  final String answer;
  const _Faq(this.question, this.answer);
}
