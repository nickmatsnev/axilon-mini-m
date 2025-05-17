import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';

class UssdSetupPage extends StatelessWidget {
  const UssdSetupPage({super.key});
  Future<void> dialUssd(String ussdCode) async {
    final encodedUssd = Uri.encodeComponent(ussdCode);
    final url = 'tel:$encodedUssd';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Невозможно запустить $url';
    }
  }

  /// A helper function (if needed) that returns the full set of instructions.
  /// (Not used directly in the UI since the UssdInfoWidget is used.)
  List<String> getUssdInstructions(String? phoneNumber) {
    if (phoneNumber != null) {
      if (phoneNumber.startsWith("34")) {
        return [
          "Dial **61*865694920**20# to set up call forwarding for no answer.",
          "Dial **62*865694920# to set up call forwarding for unreachable.",
          "Dial **67*865694920# to set up call forwarding for busy.",
        ];
      } else if (phoneNumber.startsWith("420")) {
        return [
          "Dial **61*910928777**20# to set up call forwarding for no answer.",
          "Dial **62*910928777# to set up call forwarding for unreachable.",
          "Dial **67*910928777# to set up call forwarding for busy.",
        ];
      } else if (phoneNumber.startsWith("1")) {
        return [
          "Dial **61*2369362050**20# to set up call forwarding for no answer.",
          "Dial **62*2369362050# to set up call forwarding for unreachable.",
          "Dial **67*2369362050# to set up call forwarding for busy.",
        ];
      } else if (phoneNumber.startsWith("33")) {
        return [
          "Dial **61*644604261**20# to set up call forwarding for no answer.",
          "Dial **62*644604261# to set up call forwarding for unreachable.",
          "Dial **67*644604261# to set up call forwarding for busy.",
        ];
      } else if (phoneNumber.startsWith("357")) {
        return [
          "Dial **61*25030950**20# to set up call forwarding for no answer.",
          "Dial **62*25030950# to set up call forwarding for unreachable.",
          "Dial **67*25030950# to set up call forwarding for busy.",
        ];
      } else if (phoneNumber.startsWith("7")) {
        return [
          "Dial **61*+79014172717**20# to set up call forwarding for no answer.",
          "Dial **62*+79014172717# to set up call forwarding for unreachable.",
          "Dial **67*+79014172717# to set up call forwarding for busy.",
        ];
      }
    }
    return [
      "Dial **61*2369362050**20# to set up call forwarding for no answer.",
      "Dial **62*2369362050# to set up call forwarding for unreachable.",
      "Dial **67*2369362050# to set up call forwarding for busy.",
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final phoneNumber = authProvider.user?['phone_number'];
    final translationProvider = Provider.of<TranslationProvider>(context, listen: true);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8EDFF), Color(0xFFF9FBFE)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        // Removed any Drawer
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            translationProvider.t('USSD Setup'),
            style: const TextStyle(fontFamily: 'DrukTextWideLCG', fontSize: 18),
          ),
          backgroundColor: Colors.indigo,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Display a short, informative USSD widget
              UssdInfoWidget(phoneNumber: phoneNumber),
              const SizedBox(height: 16),
              // A button that now goes to the main page (/main)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

/// A short and informative widget that displays USSD instructions
/// based on the user's phone number (by country code).
class UssdInfoWidget extends StatelessWidget {
  final String? phoneNumber;
  const UssdInfoWidget({Key? key, required this.phoneNumber}) : super(key: key);

  /// Returns a short list (one instruction) based on the phone number.
  List<String> getInstructions() {
    if (phoneNumber != null) {
      if (phoneNumber!.startsWith("34")) {
        return ["Dial **61*865694920**20# to set up call forwarding for no answer.\nDial **62*865694920# to set up call forwarding for unreachable.\nDial **67*865694920# to set up call forwarding for busy."];
      } else if (phoneNumber!.startsWith("420")) {
        return ["Dial **61*910928777**20# to set up call forwarding for no answer.\nDial **62*910928777# to set up call forwarding for unreachable.\nDial **67*910928777# to set up call forwarding for busy."];
      } else if (phoneNumber!.startsWith("1")) {
        return ["Dial **61*2369362050**20# to set up call forwarding for no answer.\nDial **62*2369362050# to set up call forwarding for unreachable.\nDial **67*2369362050# to set up call forwarding for busy."];
      } else if (phoneNumber!.startsWith("33")) {
        return ["Dial **61*644604261**20# to set up call forwarding for no answer.\nDial **62*644604261# to set up call forwarding for unreachable.\nDial **67*644604261# to set up call forwarding for busy."];
      } else if (phoneNumber!.startsWith("357")) {
        return ["Dial **61*25030950**20# to set up call forwarding for no answer.\nDial **62*25030950# to set up call forwarding for unreachable.\nDial **67*25030950# to set up call forwarding for busy."];
      } else if (phoneNumber!.startsWith("7")) {
        return ["Dial **61*+79014172717**20# to set up call forwarding for no answer.\nDial **62*+79014172717# to set up call forwarding for unreachable.\nDial **67*+79014172717# to set up call forwarding for busy."];
      }
    }
    return ["Dial **61*2369362050**20# to set up call forwarding for no answer."];
  }

  @override
  Widget build(BuildContext context) {
    final translationProvider = Provider.of<TranslationProvider>(context, listen: true);
    final instructions = getInstructions();
    return Card(
      color: const Color.fromRGBO(220, 223, 253, 0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              translationProvider.t('How to Set Up Call Forwarding'),
              style: const TextStyle(
                fontFamily: 'DrukTextWideLCG',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              phoneNumber != null
                  ? '${translationProvider.t('Your phone number')}: $phoneNumber'
                  : translationProvider.t('Unable to fetch your phone number.'),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ...instructions.map(
                  (instruction) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  translationProvider.t(instruction),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
