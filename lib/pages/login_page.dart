import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/countries.dart';
import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  String? completePhoneNumber; // store the full phone number
  bool isLoading = false;

  // Allowed country codes
  final List<String> allowedCountryCodes = ['US', 'CZ', 'ES', 'FR', 'CY', 'RU'];
  late List<Country> allowedCountries;

  @override
  void initState() {
    super.initState();
    // Filter the allowed countries
    allowedCountries = countries.where((c) {
      return allowedCountryCodes.contains(c.code);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Gradient background
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color.fromRGBO(187, 200, 253, 1), Color.fromRGBO(232, 239, 255, 1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        // Make the Scaffold transparent to show the gradient
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                shadowColor: Colors.transparent,
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Heading
                      const Text(
                        'Добро пожаловать в Axilon',
                        style: TextStyle(
                          fontFamily: 'DrukTextWideLCG', // or your DrukTextLCG
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      )
                          .animate()
                          .fade(duration: 800.ms)
                          .slideY(begin: -0.3, curve: Curves.easeOut),
                      const SizedBox(height: 20),

                      // Phone Input
                      IntlPhoneField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          labelText: 'Номер телефона',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        initialCountryCode: 'CZ',
                        countries: allowedCountries,
                        onChanged: (phone) {
                          completePhoneNumber = phone.completeNumber.replaceAll('+', '');
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Input
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Login Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),

                          ),
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                          if (completePhoneNumber == null ||
                              passwordController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Пожалуйста, сперва введите правильные телефонный номер и пароль.'),
                              ),
                            );
                            return;
                          }

                          setState(() => isLoading = true);

                          try {
                            await Provider.of<AuthProvider>(context, listen: false).login(
                              completePhoneNumber!,
                              passwordController.text,
                            );
                            final userLang = await Provider.of<AuthProvider>(context, listen: false).user?['lang'] ?? 'ru';

                            // Now grab your TranslationProvider from the context
                            final translation = Provider.of<TranslationProvider>(context, listen: false);

                            // Load that language so the UI updates
                            await translation.loadLanguage(userLang);

                            Navigator.pushReplacementNamed(context, '/main');
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          } finally {
                            setState(() => isLoading = false);
                          }
                        },
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('ВХОД', style: TextStyle(fontSize: 16, fontFamily: 'DrukTextWideLCG')),
                      ),
                      const SizedBox(height: 10),

                      // Register Button
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/register'),
                        child: const Text("Отсутствует учётная запись? Зарегистрируйся!"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
