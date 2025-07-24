import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/countries.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final phoneController = TextEditingController();
  final newPasswordController = TextEditingController();
  String? completePhone;
  bool phoneValid = false;
  bool isLoading = false;

  Future<void> checkPhoneExists() async {
    setState(() => isLoading = true);
    final url = Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/by-phone-unverified/${completePhone!}');
    final res = await http.get(url, headers: {'Authorization': 'Bearer dummy'}); // or skip middleware
    setState(() => isLoading = false);
    if (res.statusCode == 200) {
      setState(() => phoneValid = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Пользователь не найден')));
    }
  }

  Future<void> submitNewPassword() async {
    if (newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Пароль слишком короткий')));
      return;
    }

    setState(() => isLoading = true);
    final res = await http.post(
      Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone_number': completePhone,
        'new_password': newPasswordController.text,
      }),
    );
    setState(() => isLoading = false);

    if (res.statusCode == 200) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Пароль успешно обновлён')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка при обновлении пароля')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Сброс пароля')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            IntlPhoneField(
              controller: phoneController,
              initialCountryCode: 'CZ',
              countries: countries.where((c) => ['US', 'CZ', 'ES', 'FR', 'CY', 'RU'].contains(c.code)).toList(),
              decoration: InputDecoration(labelText: 'Телефон', border: OutlineInputBorder()),
              onChanged: (phone) {
                completePhone = phone.completeNumber.replaceAll('+', '');
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isLoading ? null : checkPhoneExists,
              child: Text('Проверить номер'),
            ),
            if (phoneValid) ...[
              const SizedBox(height: 20),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Новый пароль', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : submitNewPassword,
                child: Text('Сбросить пароль'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
