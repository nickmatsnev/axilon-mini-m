import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../providers/auth_provider.dart';

class ScenarioAdminWidget extends StatefulWidget {
  const ScenarioAdminWidget({Key? key}) : super(key: key);

  @override
  _ScenarioAdminWidgetState createState() => _ScenarioAdminWidgetState();
}

class _ScenarioAdminWidgetState extends State<ScenarioAdminWidget> {
  bool _loading = true;
  List<Map<String, dynamic>> _scenarios = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadScenarios();
  }

  Future<void> _loadScenarios() async {
    setState(() => _loading = true);
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    final uri = Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios');
    final resp = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });

    if (resp.statusCode == 200) {
      final List<dynamic> raw = jsonDecode(resp.body);
      setState(() {
        _scenarios = raw.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    }

    setState(() => _loading = false);
  }

  Future<void> _deleteScenario(dynamic id) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    final uri = Uri.parse(
        'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/$id');
    final resp = await http.delete(uri, headers: {
      'Authorization': 'Bearer $token',
    });
    if (resp.statusCode == 200) {
      _loadScenarios();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete scenario')),
      );
    }
  }

  Future<void> _openEditDialog([Map<String, dynamic>? existing]) async {
    final _formKey = GlobalKey<FormState>();
    String title = existing?['name'] ?? '';
    String description = existing?['description'] ?? '';

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add Scenario' : 'Edit Scenario'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: title,
                decoration: const InputDecoration(labelText: 'Name'),
                onSaved: (v) => title = v?.trim() ?? '',
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                initialValue: description,
                decoration: const InputDecoration(labelText: 'Description'),
                onSaved: (v) => description = v?.trim() ?? '',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              _formKey.currentState!.save();

              final token =
                  Provider.of<AuthProvider>(context, listen: false).token;
              if (token == null) return;

              final body = jsonEncode({
                'name': title,
                'description': description,
              });

              http.Response resp;
              if (existing == null) {
                resp = await http.post(
                  Uri.parse(
                      'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                  body: body,
                );
              } else {
                final id = existing['scenario_id'] ?? existing['id'];
                resp = await http.put(
                  Uri.parse(
                      'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/$id'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                  body: body,
                );
              }

              if (resp.statusCode == 200 || resp.statusCode == 201) {
                Navigator.pop(context);
                _loadScenarios();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Save failed')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _scenarios.where((s) {
      if (_searchQuery.isEmpty) return true;
      final values = s.values.map((v) => v.toString().toLowerCase()).join(' ');
      return values.contains(_searchQuery.toLowerCase());
    }).toList();

    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search scenarios...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openEditDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No scenarios found.'))
              : ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final sc = filtered[i];
              final id = sc['scenario_id'] ?? sc['id'];
              final name = sc['name'] ?? '';
              return ListTile(
                title: Text(name),
                subtitle: Text(id.toString()),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openEditDialog(sc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteScenario(id),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
