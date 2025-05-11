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
  final _scheduledStartController = TextEditingController();
  final _execTimeController = TextEditingController();
  final _tillController = TextEditingController();

  String _selectedType = 'chat';
  String _callMode = 'single'; // 'single' or 'repeating'
  String _selectedInterval = 'Hourly';
  DateTime? _scheduledStart;
  DateTime? _execTime;
  DateTime? _tillTime;

  bool _isSubmitting = false;

  final List<String> _typeOptions = ['chat', 'voice', 'call'];
  final List<String> _callModeOptions = ['single', 'repeating'];
  final List<String> _intervalOptions = ['Hourly', 'Daily', 'Weekly'];
  final Map<String, String> _intervalMap = {
    'Hourly': '1 hour',
    'Daily': '1 day',
    'Weekly': '1 week',
  };

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
    _scheduledStartController.dispose();
    _execTimeController.dispose();
    _tillController.dispose();
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
      'till': _tillTime?.toIso8601String(),
      'repeating': _selectedType == 'call' ? (_callMode == 'repeating') : null,
      'exec_time': (_selectedType == 'call' && _callMode == 'single')
          ? _execTime?.toIso8601String()
          : null,
      'scheduled_start': (_selectedType == 'call' && _callMode == 'repeating')
          ? _scheduledStart?.toIso8601String()
          : null,
      'scheduled_interval': (_selectedType == 'call' && _callMode == 'repeating')
          ? _intervalMap[_selectedInterval]
          : null,
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
          title: Text(t.t('Create Scenario')),
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
                        hintText: t.t('Name'),
                      ),
                      validator: (v) => v == null || v.isEmpty ? t.t('Required') : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Summary
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextFormField(
                      controller: _summaryController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: t.t('Summary'),
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
                        _callMode = 'single';
                        _promptController.clear();
                        _scheduledStartController.clear();
                        _execTimeController.clear();
                        _tillController.clear();
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
                          hintText: t.t('Prompt Value'),
                        ),
                        validator: (v) => v == null || v.isEmpty ? t.t('Required') : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else if (_selectedType == 'call') ...[
                    // call mode
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonFormField<String>(
                        value: _callMode,
                        decoration: const InputDecoration(border: InputBorder.none),
                        items: _callModeOptions
                            .map((e) => DropdownMenuItem(value: e, child: Text(t.t(e).toUpperCase())))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _callMode = v!;
                          _promptController.clear();
                          _scheduledStartController.clear();
                          _execTimeController.clear();
                          _tillController.clear();
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_callMode == 'repeating') ...[
                      // scheduled_start
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextFormField(
                          controller: _scheduledStartController,
                          readOnly: true,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: t.t('Scheduled Start'),
                          ),
                          onTap: () async {
                            final dt = await _pickDateTime();
                            if (dt != null) {
                              setState(() {
                                _scheduledStart = dt;
                                _scheduledStartController.text = DateFormat('yyyy-MM-dd HH:mm').format(dt);
                              });
                            }
                          },
                          validator: (v) => v == null || v.isEmpty ? t.t('Required') : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // scheduled_interval
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonFormField<String>(
                          value: _selectedInterval,
                          decoration: const InputDecoration(border: InputBorder.none),
                          items: _intervalOptions
                              .map((e) => DropdownMenuItem(value: e, child: Text(t.t(e))))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _selectedInterval = v!;
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // till (optional)
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextFormField(
                          controller: _tillController,
                          readOnly: true,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: t.t('Till (optional)'),
                          ),
                          onTap: () async {
                            final dt = await _pickDateTime();
                            if (dt != null) {
                              setState(() {
                                _tillTime = dt;
                                _tillController.text = DateFormat('yyyy-MM-dd HH:mm').format(dt);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      // exec_time
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextFormField(
                          controller: _execTimeController,
                          readOnly: true,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: t.t('Execution Time'),
                          ),
                          onTap: () async {
                            final dt = await _pickDateTime();
                            if (dt != null) {
                              setState(() {
                                _execTime = dt;
                                _execTimeController.text = DateFormat('yyyy-MM-dd HH:mm').format(dt);
                              });
                            }
                          },
                          validator: (v) => v == null || v.isEmpty ? t.t('Required') : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // prompt_value for calls
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextFormField(
                        controller: _promptController,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: t.t('Prompt Value'),
                        ),
                        validator: (v) => v == null || v.isEmpty ? t.t('Required') : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Submit button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: Text(_isSubmitting ? t.t('Submitting...') : t.t('Create')),
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
