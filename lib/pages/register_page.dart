import 'package:flutter/material.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import 'otp_verification_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  String? selectedCountryIso; // e.g. "CZ", "US"
  String? selectedDialCode;   // e.g. "+420"

  bool isLoading = false;

  // Allowed country codes
  final List<String> allowedCountryCodes = ['US', 'CZ', 'ES', 'FR', 'CY', 'RU'];
  late List<Country> allowedCountries;

  @override
  void initState() {
    super.initState();
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
                        'Register',
                        style: TextStyle(
                          fontFamily: 'DrukTextWideLCG', // or DrukTextLCG
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
                          labelText: 'First Name',
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
                          labelText: 'Last Name',
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
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        initialCountryCode: 'CZ',
                        countries: allowedCountries,
                        onChanged: (phone) {
                          selectedDialCode = phone.countryCode;
                          selectedCountryIso = phone.countryISOCode;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
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
                        onPressed: isLoading
                            ? null
                            : () async {
                          setState(() => isLoading = true);
                          try {
                            final formattedPhone =
                                "${selectedDialCode ?? ''}${phoneController.text}";
                            final countryIso = selectedCountryIso ?? 'Unknown';

                            await Provider.of<AuthProvider>(context, listen: false)
                                .register(
                              firstNameController.text,
                              lastNameController.text,
                              formattedPhone,
                              passwordController.text,
                              countryIso,
                            );

                            Navigator.pushReplacementNamed(context, '/ussd');
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
                            : const Text('REGISTER', style: TextStyle(fontSize: 16, fontFamily: 'DrukTextWideLCG')),
                      ),
                      const SizedBox(height: 10),

                      // Already have an account
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                        child: const Text('Already have an account? Log in'),
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
