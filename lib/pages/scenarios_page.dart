import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';
import 'create_scenario_page.dart';
import 'edit_scenario_page.dart';

class ScenariosPage extends StatefulWidget {
  const ScenariosPage({Key? key}) : super(key: key);

  @override
  _ScenariosPageState createState() => _ScenariosPageState();
}

class _ScenariosPageState extends State<ScenariosPage> {
  bool _isLoading = true;
  List<dynamic> _scenarios = [];

  @override
  void initState() {
    super.initState();
    _fetchScenarios();
  }

  Future<void> _fetchScenarios() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?['user_id'];
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final resp = await http.get(
      Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/scenarios/getAll/$userId'),
      headers: {'Authorization': 'Bearer ${auth.token}'},
    );
    if (resp.statusCode == 200) {
      setState(() {
        _scenarios = jsonDecode(resp.body);
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<TranslationProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('My Scenarios')),
        backgroundColor: const Color(0xFFE8EDFF),
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _scenarios.isEmpty
            ? Center(child: Text(t.t('No scenarios found.')))
            : ListView.builder(
          itemCount: _scenarios.length,
          itemBuilder: (_, i) {
            final scn = _scenarios[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(scn['scenario_name'] ?? '—'),
                subtitle: Text(scn['summary'] ?? '—'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditScenarioPage(scenarioId: scn['id']),
                    ),
                  );
                  _fetchScenarios();
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateScenarioPage()),
          );
          _fetchScenarios();
        },
      ),
    );
  }
}
