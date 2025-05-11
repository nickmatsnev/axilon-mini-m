import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';
import '../widgets/drawer_widget.dart';

class ProfilePage extends StatefulWidget {
  ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isRejectAll = false; // local toggle state

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user != null && user['reject_all'] != null) {
      _isRejectAll = user['reject_all'] == true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: true);
    final translationProvider = Provider.of<TranslationProvider>(context, listen: true);
    final user = authProvider.user;
    if (user == null) {
      // If user is null, they've logged out or the account was deleted
      Future.microtask(() {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(translationProvider.t("YOUR_PROFILE")),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // A dropdown to pick language
          DropdownButton<String>(
            value: translationProvider.currentLang,
            underline: const SizedBox(),
            icon: const Icon(Icons.language, color: Colors.white),
            dropdownColor: Colors.indigo,
            items: const [
              DropdownMenuItem(
                value: 'en',
                child: Text('English', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'es',
                child: Text('Español', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'fr',
                child: Text('Français', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'cs',
                child: Text('Čeština', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'de',
                child: Text('Deutsch', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'ru',
                child: Text('Русский', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'fa',
                child: Text('فارسی', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'el',
                child: Text('Ελληνικά', style: TextStyle(color: Colors.white)),
              ),
            ],
            onChanged: (String? newLang) async {
              if (newLang != null) {
                final token = authProvider.token;
                await translationProvider.setLanguage(newLang, token!, user['user_id']);
              }
            },
          ),
        ],
      ),
      drawer: buildDrawer(context), // Reusable Drawer
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.indigoAccent,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              '${user['first_name']} ${user['last_name']}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "${translationProvider.t("Phone")}: ${user['phone_number']}",
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 20),

            // ***********************
            // Reject All Calls Toggle
            // ***********************
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    translationProvider.t("REJECT_ALL_CALLS"),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                Switch(
                  value: _isRejectAll,
                  onChanged: (bool val) async {
                    // Attempt to update the user's 'reject_all' in the backend
                    final token = authProvider.token;
                    final userId = user['user_id'];
                    if (token == null || userId == null) return;

                    final url = Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId/reject-all');
                    try {
                      final response = await http.put(
                        url,
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer $token'
                        },
                        body: jsonEncode({"reject_all": val}),
                      );

                      if (response.statusCode == 200) {
                        final respData = jsonDecode(response.body);
                        final updatedUser = respData['user'];
                        authProvider.setUser(updatedUser);
                        setState(() {
                          _isRejectAll = val;
                        });
                      } else {
                        print("Error updating reject_all: ${response.body}");
                      }
                    } catch (e) {
                      print("Exception updating reject_all: $e");
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ***********************
            // Change Phone
            // ***********************
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: translationProvider.t("NEW_PHONE_NUMBER"),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                // TODO: Implement "Change Phone" logic
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(translationProvider.t("PHONE_UPDATED_SUCCESS"))),
                );
              },
              child: Text(
                translationProvider.t("CHANGE_PHONE"),
                style: const TextStyle(color: Colors.white),
              ),
            ),

            const SizedBox(height: 30),
            // ***********************
            // Change Password
            // ***********************
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: translationProvider.t("CHANGE_PASSWORD"),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                // TODO: Implement "Change Password" logic
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(translationProvider.t("PASSWORD_UPDATED_SUCCESS"))),
                );
              },
              child: Text(
                translationProvider.t("CHANGE_PASSWORD"),
                style: const TextStyle(color: Colors.white),
              ),
            ),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 20),

            // ***********************
            // Delete Account
            // ***********************
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                // Show a confirmation dialog
                showDialog(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: Text(translationProvider.t("DELETE_ACCOUNT")),
                    content: Text(translationProvider.t("DELETE_ACCOUNT_CONFIRM")),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text(translationProvider.t("CANCEL")),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(dialogCtx); // close the dialog
                          final userId = user['user_id'];
                          if (userId == null) return;

                          try {
                            final token = authProvider.token;
                            if (token == null) return;
                            await authProvider.deleteUser(userId, token);

                            authProvider.logout();
                            Navigator.pushReplacementNamed(context, '/');
                          } catch (error) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error deleting account: $error"))
                            );
                          }
                        },
                        child: Text(
                          translationProvider.t("DELETE"),
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: Text(
                translationProvider.t("DELETE_ACCOUNT"),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
