import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';

import '../providers/auth_provider.dart';
import 'edit_scenario_page.dart';

class ResumeScenarioPage extends StatefulWidget {
  final String scenarioId;
  final String chatId;
  const ResumeScenarioPage({
    required this.scenarioId,
    required this.chatId,
    Key? key,
  }) : super(key: key);

  @override
  _ResumeScenarioPageState createState() => _ResumeScenarioPageState();
}

class _ResumeScenarioPageState extends State<ResumeScenarioPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchChat();
  }

  Future<void> _fetchChat() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bearerToken = authProvider.token ?? '';
    final resp = await http.get(
      Uri.parse(
        'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/scenario-chat/${widget.chatId}/messages',
      ),
      headers: {
        'Authorization': 'Bearer $bearerToken',
      },
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as List;
      setState(() {
        _messages = data.map((e) => e as Map<String, dynamic>).toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load messages (${resp.statusCode})')),
      );
    }
  }

  Future<void> _sendReply() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bearerToken = authProvider.token ?? '';
    final resp = await http.post(
      Uri.parse(
        'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/scenario-chat/message',
      ),
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'chat_id': widget.chatId,
        'content': text,
      }),
    );

    if (resp.statusCode == 200) {
      _controller.clear();
      await _fetchChat();
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message (${resp.statusCode})')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Scenario'),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditScenarioPage(
                    scenarioId: widget.scenarioId,
                  ),
                ),
              );
            },
          )
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                final isUser = msg['sender_type'] == 'user';
                return Align(
                  alignment:
                  isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.symmetric(
                        vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.white
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg['content']),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(controller: _controller),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendReply,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
