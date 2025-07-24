import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';

class UssdSetupPage extends StatelessWidget {
  const UssdSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final phoneNumber = authProvider.user?['phone_number'] as String?;
    final translationProvider =
    Provider.of<TranslationProvider>(context, listen: true);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8EDFF), Color(0xFFF9FBFE)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            translationProvider.t('USSD Setup'),
            style:
            const TextStyle(fontFamily: 'DrukTextWideLCG', fontSize: 18),
          ),
          backgroundColor: Colors.indigo,
          actions: [
            IconButton(
              tooltip: translationProvider.t('Copy All Codes'),
              icon: const Icon(Icons.copy_all),
              onPressed: () async {
                final actions = 
                UssdInfoData(phoneNumber).generateActions();
                final all = actions.map((a) => a.code).join('\n');
                await copyToClipboard(context, all,
                    translationProvider.t('All USSD codes copied'));
              },
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              UssdInfoWidget(phoneNumber: phoneNumber),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/choice');
                  },
                  child: Text(
                    translationProvider.t('Go to Assistant selection'),
                    style: const TextStyle(
                      fontFamily: 'DrukTextWideLCG',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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

/// Model representing a single USSD forwarding action
class UssdAction {
  final String title;
  final String description;
  final String code; // complete code to dial
  UssdAction({
    required this.title,
    required this.description,
    required this.code,
  });
}

/// Helper that decides forwarding target numbers by country prefix
class UssdInfoData {
  final String? phoneNumber;
  late final String target; // forwarding destination (without modifiers)
  UssdInfoData(this.phoneNumber) {
    target = _resolveTarget(phoneNumber);
  }

  String _resolveTarget(String? p) {
    if (p == null) return '2369362050';
    if (p.startsWith('34')) return '865694920';
    if (p.startsWith('420')) return '910928777';
    if (p.startsWith('1')) return '2369362050';
    if (p.startsWith('33')) return '644604261';
    if (p.startsWith('357')) return '25030950';
    if (p.startsWith('7')) return '+79014172717';
    return '2369362050';
  }

  List<UssdAction> generateActions() {
    // 61 = no answer (with timeout **20#)
    // 62 = unreachable
    // 67 = busy
    return [
      UssdAction(
        title: 'No Answer',
        description: 'Forward if you do not pick up within 20s.',
        code: '**61*$target**20#',
      ),
      UssdAction(
        title: 'Unreachable',
        description: 'Forward when phone is off/out of coverage.',
        code: '**62*$target#',
      ),
      UssdAction(
        title: 'Busy',
        description: 'Forward when line is engaged.',
        code: '**67*$target#',
      ),
      UssdAction(
        title: 'Forward all calls',
        description: 'Always forward the calls to the assistant.',
        code: '**21*$target#',
      ),
      UssdAction(
        title: 'Cancel call forwarding',
        description: 'If you wish to cancel call forwarding, use this option.',
        code: '##21#',
      ),
    ];
  }
}

/// Copy helper (uses ScaffoldMessenger)
Future<void> copyToClipboard(
    BuildContext context, String text, String successMsg) async {
  // ignore: deprecated_member_use
  await Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(successMsg)),
  );
}

/// Launch dialer with given USSD code
Future<void> dialUssdCode(String code) async {
  // Need to encode #, * etc.
  final encoded = Uri.encodeComponent(code);
  final uri = Uri.parse('tel:$encoded');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    throw 'Cannot launch $uri';
  }
}

/// Top info widget with per‑action cards
class UssdInfoWidget extends StatelessWidget {
  final String? phoneNumber;
  const UssdInfoWidget({Key? key, required this.phoneNumber}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final translationProvider =
    Provider.of<TranslationProvider>(context, listen: true);

    final data = UssdInfoData(phoneNumber);
    final actions = data.generateActions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: const Color.fromRGBO(220, 223, 253, 0.85),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translationProvider
                      .t('How to Set Up Call Forwarding')
                      .toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'DrukTextWideLCG',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  phoneNumber != null
                      ? '${translationProvider.t('Your phone number')}: $phoneNumber'
                      : translationProvider
                      .t('Unable to fetch your phone number.'),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Text(
                  translationProvider.t(
                      'Tap DIAL to execute code or COPY to copy it.'),
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Grid / list of action cards
        LayoutBuilder(
          builder: (ctx, constraints) {
            final isWide = constraints.maxWidth > 600;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: actions.map((a) {
                final w = isWide
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;
                return SizedBox(
                  width: w,
                  child: _ActionCard(action: a),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final UssdAction action;
  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final translationProvider =
    Provider.of<TranslationProvider>(context, listen: true);

    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.phone_forwarded,
                  color: Colors.indigo.shade400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    translationProvider.t(action.title),
                    style: const TextStyle(
                      fontFamily: 'DrukTextWideLCG',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              translationProvider.t(action.description),
              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              padding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
              child: SelectableText(
                action.code,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'RobotoMono',
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(translationProvider.t('COPY')),
                    onPressed: () => copyToClipboard(
                        context,
                        action.code,
                        translationProvider
                            .t('USSD code copied to clipboard')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo,
                      side: BorderSide(color: Colors.indigo.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.call, size: 18, color: Colors.white),
                    label: Text(
                      translationProvider.t('DIAL'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    onPressed: () async {
                      try {
                        await dialUssdCode(action.code);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
