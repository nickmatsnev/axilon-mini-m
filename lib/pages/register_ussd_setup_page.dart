import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class UssdSetupPage extends StatelessWidget {
  const UssdSetupPage({Key? key}) : super(key: key);

  List<String> getUssdInstructions(String? phoneNumber) {
    if (phoneNumber != null) {
      if (phoneNumber.startsWith("34")) {
        return [
          "Dial **61*865690278**20# to set up call forwarding for no answer.",
          "Dial **62*865690278# to set up call forwarding for unreachable.",
          "Dial **67*865690278# to set up call forwarding for busy.",
        ];
      } else if (phoneNumber.startsWith("420")) {
        return [
          "Dial **61*910928777**20# to set up call forwarding for no answer.",
          "Dial **62*910928777# to set up call forwarding for unreachable.",
          "Dial **67*910928777# to set up call forwarding for busy.",
        ];
      }
    }
    return [
      "Dial **61*865690278**20# to set up call forwarding for no answer.",
      "Dial **62*865690278# to set up call forwarding for unreachable.",
      "Dial **67*865690278# to set up call forwarding for busy.",
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final phoneNumber = authProvider.user?['phone_number']; // Fetch the user's phone number
    final ussdInstructions = getUssdInstructions(phoneNumber);

    return Scaffold(
      appBar: AppBar(
        title: const Text('USSD Setup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How to Set Up Call Forwarding',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              phoneNumber != null
                  ? 'Your phone number: $phoneNumber'
                  : 'Unable to fetch your phone number.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ...ussdInstructions.map((instruction) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                instruction,
                style: const TextStyle(fontSize: 16),
              ),
            )),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/settings');
          },
          child: const Text(
            'Go to Assistant Selection',
            style: TextStyle(fontSize: 16),
          ),
),
      ),
    );
  }
}
