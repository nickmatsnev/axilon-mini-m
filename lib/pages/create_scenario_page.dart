import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';

class CreateScenarioPage extends StatefulWidget {
  const CreateScenarioPage({Key? key}) : super(key: key);

  @override
  State<CreateScenarioPage> createState() => _CreateScenarioPageState();
}

class _CreateScenarioPageState extends State<CreateScenarioPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _summaryController = TextEditingController();
  final _promptController = TextEditingController();

  String _selectedType = 'chat';
  bool _isSubmitting = false;

  final List<String> _typeOptions = ['voice'];

  Future<DateTime?> _pickDateTime() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return null;
    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _summaryController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    final userId = auth.user?['user_id'];
    if (token == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication error')),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    final id = const Uuid().v4();
    final body = {
      'id': id,
      'scenario_name': _nameController.text.trim(),
      'summary': _summaryController.text.trim(),
      'status': true,
      'scenario_type': _selectedType,
      'add_to_chat_prompt': _selectedType == 'chat',
      'add_to_voice_prompt': _selectedType == 'voice',
      'prompt_value': _promptController.text.trim(),
      'user_id': userId,
    };

    final url = Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/create');
    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    setState(() => _isSubmitting = false);
    if (resp.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scenario created successfully')),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${resp.body}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<TranslationProvider>(context, listen: true);

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
          backgroundColor: const Color(0xFFE8EDFF),
          foregroundColor: Colors.black,
          elevation: 2,
          title: Text("Создать сценарий"),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Name
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Название",
                      ),
                      validator: (v) => v == null || v.isEmpty ? t.t('Required') : null,
                    ),
                  ),
                  const SizedBox(height: 12),

               

                  // Scenario Type
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(border: InputBorder.none),
                      items: _typeOptions
                          .map((e) => DropdownMenuItem(value: e, child: Text(t.t(e).toUpperCase())))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _selectedType = v!;
                        // reset sub-fields
                        _promptController.clear();
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Conditional fields
                  if (_selectedType == 'chat' || _selectedType == 'voice') ...[
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextFormField(
                        controller: _promptController,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: "Содержание(что скажет агент)",
                        ),
                        validator: (v) => v == null || v.isEmpty ? t.t('Обязательное поле!') : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Submit button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: Text(_isSubmitting ? t.t('Создаю...') : t.t('Создать')),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
