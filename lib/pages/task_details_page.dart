import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TaskDetailsPage extends StatefulWidget {
  final Map<String, dynamic> task;
  const TaskDetailsPage({Key? key, required this.task}) : super(key: key);

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  bool _isCancelling = false;
  bool _isMarkingRead = false;
  bool _hasFetchedLanguage = false;

  @override
  void initState() {
    super.initState();
    _markTaskAsRead();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final translationProvider = Provider.of<TranslationProvider>(context, listen: false);
      final token = authProvider.token ?? "";
      final user = authProvider.user;
      if (!_hasFetchedLanguage && token.isNotEmpty && user != null) {
        translationProvider.fetchUserLanguage(token, user['user_id']).catchError((error) {
          print("Error fetching language: $error");
        });
        _hasFetchedLanguage = true;
      }
    });

  }


  Future<void> _markTaskAsRead() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final taskId = widget.task['task_id'];
    if (taskId == null) return;

    setState(() => _isMarkingRead = true);
    try {
      final url = Uri.parse(
          'https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/tasks/$taskId/setRead');
      await http.get(
        url,
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );
    } catch (e) {
      // Error handling if needed
    } finally {
      setState(() => _isMarkingRead = false);
    }
  }

  Future<void> _cancelTask() async {
    setState(() => _isCancelling = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final taskId = widget.task['task_id'];
    final body = {
      "task_text": widget.task['task_text'],
      "task_time": widget.task['task_time'],
      "task_status": "failed",
      "task_resolution": widget.task['task_resolution'],
      "task_conversation": widget.task['task_conversation'],
      "dest_phone_number": widget.task['dest_phone_number'],
    };

    try {
      final response = await http.put(
        Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/tasks/$taskId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task cancelled successfully')),
        );
        Navigator.pop(context, 'cancelled');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel task: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling task: $e')),
      );
    } finally {
      setState(() => _isCancelling = false);
    }
  }


  Widget _buildDetailRow(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title: ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return '🔵 Pending';
      case 'in_progress':
        return '🟡 In Progress';
      case 'done':
        return '🟢 Completed';
      case 'failed':
        return '🔴 Failed';
      default:
        return '⚪ Unknown';
    }
  }

  Widget _buildConversation(String conversation) {
    final messages = parseTranscript(conversation);
    if (messages.isEmpty) {
      return Text(
        "No conversation available.",
        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
      );
    }
    return SizedBox(
      height: 200,
      child: ListView.builder(
        reverse: true,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          return _buildChatBubble(role: msg['role']!, content: msg['content']!);
        },
      ),
    );
  }

  Widget _buildChatBubble({required String role, required String content}) {
    bool isAgent = role == 'AGENT';
    bool isUser = role == 'USER';
    Alignment alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    Color bubbleColor = isUser ? Colors.indigo.shade100 : Colors.indigo.shade200;
    BorderRadius borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: isUser ? const Radius.circular(12) : const Radius.circular(0),
      bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(12),
    );
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
        ),
        child: Text(
          content,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),
    );
  }

  List<Map<String, String>> parseTranscript(String? rawTranscript) {
    if (rawTranscript == null || rawTranscript.trim().isEmpty) {
      return [];
    }
    final lines = rawTranscript.split('\n');
    final messages = <Map<String, String>>[];
    for (var line in lines) {
      final idx = line.indexOf(':');
      if (idx != -1) {
        final role = line.substring(0, idx).trim().toUpperCase();
        final msgText = line.substring(idx + 1).trim();
        messages.add({'role': role, 'content': msgText});
      } else {
        messages.add({'role': 'UNKNOWN', 'content': line.trim()});
      }
    }
    return messages.reversed.toList(); // latest at bottom
  }

  @override
  Widget build(BuildContext context) {
    final translationProvider = Provider.of<TranslationProvider>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          translationProvider.t("Task Details"),
          style: const TextStyle(
            fontFamily: 'DrukTextWideLCG',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        foregroundColor: Colors.indigo,
        backgroundColor: const Color(0xFFE8EDFF),
      ),
      body: _isMarkingRead
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Task Details Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      translationProvider.t('Task Text'),
                      widget.task['task_text'] ?? '',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      translationProvider.t('Task Time'),
                      widget.task['task_time'] ?? '',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      translationProvider.t('Status'),
                      _formatStatus(widget.task['task_status']),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      translationProvider.t('Resolution'),
                      widget.task['task_resolution'] ?? '',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      translationProvider.t('Destination Phone'),
                      widget.task['dest_phone_number'] ?? '',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Task Conversation (only if completed)
            if (widget.task['task_status'] == 'done' &&
                widget.task['task_conversation'] != null &&
                widget.task['task_conversation'].toString().trim().isNotEmpty)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.indigo.shade50,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translationProvider.t('Conversation'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.shade100,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _buildConversation(widget.task['task_conversation']),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 30),
            // Cancel Task Button
            if (widget.task['task_status'] == 'pending' ||
                widget.task['task_status'] == 'in progress')
              ElevatedButton.icon(
                onPressed: _isCancelling ? null : _cancelTask,
                icon: _isCancelling
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Icon(Icons.cancel, color: Colors.pink),
                label: Text(
                  translationProvider.t("CANCEL TASK"),
                  style: const TextStyle(fontFamily: 'DrukTextWideLCG', fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
