import 'dart:convert';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/translation_provider.dart';

class CallDetailsPage extends StatefulWidget {
  final Map<String, dynamic> call;
  const CallDetailsPage({Key? key, required this.call}) : super(key: key);

  @override
  State<CallDetailsPage> createState() => _CallDetailsPageState();
}

class _CallDetailsPageState extends State<CallDetailsPage> {
  bool _isMarkingRead = false;
  Map<String, String> _contactsMap = {};
  bool _hasFetchedLanguage = false;

  // AUDIO using just_audio
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _markCallAsRead();
    _loadContacts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final translationProvider =
      Provider.of<TranslationProvider>(context, listen: false);
      final token = authProvider.token ?? "";
      final user = authProvider.user;
      if (!_hasFetchedLanguage && token.isNotEmpty && user != null) {
        translationProvider.fetchUserLanguage(token, user['user_id']).catchError((error) {
          print("Error fetching language: $error");
        });
        _hasFetchedLanguage = true;
      }
    });

    // Setup the audio player from just_audio.
    _audioPlayer = AudioPlayer();
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _markCallAsRead() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final callId = widget.call['call_id'];
    if (callId == null) return;

    setState(() => _isMarkingRead = true);
    try {
      final url = Uri.parse(
        'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/phone-calls/$callId/setRead',
      );
      await http.get(
        url,
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );
    } catch (_) {
      // Handle error if needed
    } finally {
      setState(() => _isMarkingRead = false);
    }
  }

  /// Load contacts from phone and map normalized number to display name.
  Future<void> _loadContacts() async {
    if (await FlutterContacts.requestPermission()) {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final Map<String, String> mapping = {};
      for (var contact in contacts) {
        for (var phone in contact.phones) {
          String normalized = phone.number.replaceAll(RegExp(r'\D'), '');
          mapping[normalized] = contact.displayName;
        }
      }
      setState(() {
        _contactsMap = mapping;
      });
    }
  }

  /// Return a contact name if found; otherwise, the raw phone.
  String _getContactName(String phone) {
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    return _contactsMap[normalized] ?? phone;
  }


  /// Called by a Play/Pause button to toggle call audio.
  Future<void> _playPauseAudio() async {
    final raw = widget.call['audio'] as String? ?? '';
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audio for this call')),
      );
      return;
    }

    // Normalize URL
    final audioUrl = raw.startsWith('http')
        ? raw
        : raw.startsWith('/')
        ? 'https://axilon-mini-be-e5732e59dadc.herokuapp.com$raw'
        : 'https://axilon-mini-be-e5732e59dadc.herokuapp.com/$raw';

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated')),
      );
      return;
    }

    try {
      if (!_isPlaying) {
        setState(() => _isPlaying = true);

        // If it's an S3 URL, download without auth and play locally
        if (audioUrl.contains('.amazonaws.com')) {
          final resp = await http.get(Uri.parse(audioUrl));
          if (resp.statusCode != 200) {
            throw Exception('S3 download failed: HTTP ${resp.statusCode}');
          }
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/call_${widget.call['call_id']}.mp3');
          await file.writeAsBytes(resp.bodyBytes, flush: true);
          await _audioPlayer.setFilePath(file.path);

        } else {
          // Your own server: fetch with Bearer, then play locally
          final resp = await http.get(
            Uri.parse(audioUrl),
            headers: { 'Authorization': 'Bearer $token' },
          );
          if (resp.statusCode != 200) {
            throw Exception('Server download failed: HTTP ${resp.statusCode}');
          }
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/call_${widget.call['call_id']}.mp3');
          await file.writeAsBytes(resp.bodyBytes, flush: true);
          await _audioPlayer.setFilePath(file.path);
        }

        await _audioPlayer.play();
      } else {
        await _audioPlayer.stop();
      }
    } catch (e) {
      debugPrint('❌ Audio load/play failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playback error: $e')),
      );
    } finally {
      setState(() => _isPlaying = _audioPlayer.playing);
    }
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
        final txt  = line.substring(idx + 1).trim();
        messages.add({'role': role, 'content': txt});
      } else {
        messages.add({'role': 'UNKNOWN', 'content': line.trim()});
      }
    }
    return messages;
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
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

  Widget _buildChatBubble({required String role, required String content}) {
    final isUser = (role == 'USER');
    Alignment alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    Color bubbleColor = isUser ? Colors.white : const Color(0xFFD8E1FF);
    final borderRadius = BorderRadius.only(
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
        ),
        child: Text(
          content,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
        ),
      ),
    );
  }

  String _formatTime(dynamic rawTime) {
    if (rawTime == null) return '---';
    try {
      final dt = DateTime.parse(rawTime.toString());
      return DateFormat('yyyy-MM-dd hh:mm a').format(dt);
    } catch (_) {
      return '---';
    }
  }

  String _formatDuration(dynamic dur) {
    if (dur == null) return 'N/A';
    final secs = dur['seconds'] ?? 0;
    final mins = dur['minutes'] ?? 0;
    final hrs  = dur['hours'] ?? 0;
    if (hrs > 0) {
      return '${hrs}h ${mins}m ${secs}s';
    } else if (mins > 0) {
      return '${mins}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  String _formatStatus(String? status) {
    if (status == null) return '---';
    switch (status.toLowerCase()) {
      case 'completed':
        return '✅ Completed';
      case 'rejected':
        return '❌ Rejected';
      case 'missed':
        return '📞 Missed';
      default:
        return '⚪ Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final translationProvider = Provider.of<TranslationProvider>(context, listen: false);
    final messages = parseTranscript(call['transcript']);

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
          elevation: 2,
          foregroundColor: Colors.black,
          title: Text(
            translationProvider.t("CALL DETAILS").toUpperCase(),
            style: const TextStyle(
              fontFamily: 'DrukTextWideLCG',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isMarkingRead
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // TOP CARD: Caller info, Start time, Duration, etc.
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        translationProvider.t('Caller'),
                        _getContactName(call['caller_phone']?.toString() ?? '---'),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        translationProvider.t('Recipient'),
                        _getContactName(call['recipient_phone']?.toString() ?? '---'),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        translationProvider.t('Start Time'),
                        _formatTime(call['start_time']),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        translationProvider.t('Duration'),
                        _formatDuration(call['duration']),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        translationProvider.t('Status'),
                        _formatStatus(call['status']),
                      ),
                      if (call['category'] != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          translationProvider.t('Category'),
                          call['category'] ?? '',
                        ),
                      ],
                      if (call['summary'] != null && call['summary'].toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          translationProvider.t('SUMMARY')+ ':',
                          style: const TextStyle(
                            fontFamily: 'DrukTextWideLCG',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          call['summary'],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // AUDIO PLAYBACK
                      if (call['audio'] != null && call['audio'].isNotEmpty)
                        Row(
                          children: [
                            Text(
                              "Аудио:",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                              color: Colors.indigo,
                              onPressed: _playPauseAudio,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // TRANSCRIPT / Conversation Title
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  translationProvider.t("CONVERSATION"),
                  style: const TextStyle(
                    fontFamily: 'DrukTextWideLCG',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Chat Bubbles Container
              Container(
                padding: const EdgeInsets.all(12.0),
                constraints: const BoxConstraints(minHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: messages.isEmpty
                    ? Center(
                  child: Text(
                    translationProvider.t("No transcript available."),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: messages.map((msg) {
                    return _buildChatBubble(
                      role: msg['role']!,
                      content: msg['content']!,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              // Button: Back to Calls
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: Text(
                    translationProvider.t('BACK TO CALLS'),
                    style: const TextStyle(
                      fontFamily: 'DrukTextWideLCG',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
