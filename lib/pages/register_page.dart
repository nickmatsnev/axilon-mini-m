// lib/pages/register_page.dart

import 'package:flutter/material.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final firstNameController = TextEditingController();
  final lastNameController  = TextEditingController();
  final phoneController     = TextEditingController();
  final passwordController  = TextEditingController();

  String? selectedCountryIso; // e.g. "CZ", "US"
  String? selectedDialCode;   // e.g. "+420"

  bool isLoading = false;

  final List<String> allowedCountryCodes = ['US', 'CZ', 'ES', 'FR', 'CY', 'RU'];
  late List<Country> allowedCountries;

  @override
  void initState() {
    super.initState();
    // Keep only the allowed countries
    allowedCountries = countries
        .where((c) => allowedCountryCodes.contains(c.code))
        .toList();
  }

  Future<void> _onRegisterPressed() async {
    setState(() {
      isLoading = true;
    });

    try {
      // — Remove/disable real FCM logic here —
      // We simply use a dummy token for now:
      const fcmToken = 'dummy-fcm-token';

      // 1) Prepare form fields
      final formattedPhone =
          '${selectedDialCode ?? ''}${phoneController.text.trim()}';
      final countryIso = selectedCountryIso ?? 'US';
      final firstName  = firstNameController.text.trim();
      final lastName   = lastNameController.text.trim();
      final password   = passwordController.text.trim();

      // 2) Call your AuthProvider.register with dummy token
      await Provider.of<AuthProvider>(context, listen: false).register(
        firstName,
        lastName,
        formattedPhone,
        password,
        countryIso,
        fcmToken,
      );

      // 3) On success, navigate on
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/ussd');
    } catch (e) {
      debugPrint('Registration error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось зарегистрироваться: $e')),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromRGBO(187, 200, 253, 1),
            Color.fromRGBO(232, 239, 255, 1),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 30,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Заголовок
                      const Text(
                        'Регистрация',
                        style: TextStyle(
                          fontFamily: 'DrukTextWideLCG',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // First Name
                      TextField(
                        controller: firstNameController,
                        decoration: InputDecoration(
                          labelText: 'Имя',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Last Name
                      TextField(
                        controller: lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Фамилия',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Phone
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
                          selectedDialCode   = phone.countryCode;
                          selectedCountryIso = phone.countryISOCode;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
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

                      // Register Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isLoading ? null : _onRegisterPressed,
                        child: isLoading
                            ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                            : const Text(
                          'Зарегистрироваться',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'DrukTextWideLCG',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Already have account?
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/');
                        },
                        child: const Text('Уже есть учётная запись? Войти'),
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
