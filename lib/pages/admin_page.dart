import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';
import '../widgets/drawer_widget.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({Key? key}) : super(key: key);

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ------------------- PROMPTS -------------------
  bool _isLoadingPrompts = false;
  List<dynamic> _prompts = [];

  // ------------------- USERS ---------------------
  bool _isLoadingUsers = false;
  List<dynamic> _users = [];
  String _userSearch = "";

  // ------------------- CALLS ---------------------
  bool _isLoadingCalls = false;
  List<dynamic> _calls = [];
  String _callSearch = "";

  // ------------------- CHATS ---------------------
  bool _isLoadingChats = false;
  List<dynamic> _chats = [];
  String _chatSearch = "";

  // ------------------- TASKS ---------------------
  bool _isLoadingTasks = false;
  List<dynamic> _tasks = [];
  String _taskSearch = "";

  // ------------------- AGENTS --------------------
  bool _isLoadingAgents = false;
  List<dynamic> _agents = [];
  String _agentsSearch = "";

  @override
  void initState() {
    super.initState();
    // We now have 6 tabs: Prompts, Users, Calls, Chats, Tasks, Agents
    _tabController = TabController(length: 6, vsync: this);

    _fetchPrompts();
    _fetchUsers();   // Important: we load users first so we can do name lookups
    _fetchCalls();
    _fetchChats();
    _fetchTasks();
    _fetchAgents();
  }

  // ------------------------------------------------------------------
  // UTILS:  Return "FirstName LastName" for a given userId, or the userId if not found
  // ------------------------------------------------------------------
  String _getUserDisplayName(String userId) {
    final user = _users.firstWhere(
          (u) => u['user_id'] == userId,
      orElse: () => null,
    );
    if (user == null) return userId; // fallback if not found
    final fname = user['first_name'] ?? '';
    final lname = user['last_name'] ?? '';
    return (fname + ' ' + lname).trim();
  }

  bool _isUserAdmin(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    if (userData['is_admin'] == true) return true;
    if (userData['is_admin'] == 1) return true;
    return false;
  }

  // ------------------------------------------------------------------
  // PROMPTS
  // ------------------------------------------------------------------
  Future<void> _fetchPrompts() async {
    setState(() => _isLoadingPrompts = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/prompts'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _prompts = data;
          _isLoadingPrompts = false;
        });
      } else {
        setState(() => _isLoadingPrompts = false);
        print("Failed to fetch prompts: ${response.body}");
      }
    } catch (err) {
      setState(() => _isLoadingPrompts = false);
      print("Error fetching prompts: $err");
    }
  }

  Future<void> _updatePrompt(String promptId, String newVal, String newDescr) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.put(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/prompts/$promptId'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "prompt_val": newVal,
          "prompt_descr": newDescr,
        }),
      );
      if (response.statusCode == 200) {
        print("Prompt updated successfully");
        _fetchPrompts();
      } else {
        print("Error updating prompt: ${response.body}");
      }
    } catch (err) {
      print("Exception updating prompt: $err");
    }
  }

  Widget _buildPromptsTab() {
    if (_isLoadingPrompts) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: _prompts.length,
      itemBuilder: (context, index) {
        final item = _prompts[index];
        final promptId = item['prompt_id'];
        final valController =
        TextEditingController(text: item['prompt_val']);
        final descrController =
        TextEditingController(text: item['prompt_descr'] ?? "");

        return Card(
          margin: const EdgeInsets.all(12.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ID: $promptId",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: descrController,
                  decoration: const InputDecoration(labelText: "Description"),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valController,
                  maxLines: 5,
                  decoration:
                  const InputDecoration(labelText: "Prompt Value"),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        _updatePrompt(
                          promptId,
                          valController.text,
                          descrController.text,
                        );
                      },
                      child: const Text("Save"),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // USERS
  // ------------------------------------------------------------------
  Future<void> _fetchUsers() async {
    setState(() => _isLoadingUsers = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _users = data;
          _isLoadingUsers = false;
        });
        print("Fetched ${data.length} users from server");
      } else {
        setState(() => _isLoadingUsers = false);
        print("Error fetching users: ${response.body}");
      }
    } catch (err) {
      setState(() => _isLoadingUsers = false);
      print("Exception fetching users: $err");
    }
  }

  Future<void> _deleteUser(String userId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final resp = await http.delete(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (resp.statusCode == 200) {
        setState(() {
          _users.removeWhere((u) => u['user_id'] == userId);
        });
      } else {
        print("Failed to delete user: ${resp.body}");
      }
    } catch (err) {
      print("Error deleting user: $err");
    }
  }
  Future<void> _toggleAdmin(String userId, bool isAdmin) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final endpoint = isAdmin ? 'unsetAdmin' : 'setAdmin';
    final url = 'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId/$endpoint';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );

      if (response.statusCode == 200) {
        print("Successfully toggled admin status for user $userId");
        // Optionally, show a success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAdmin
                ? 'User demoted from admin successfully.'
                : 'User promoted to admin successfully.'),
          ),
        );
        // Refresh the users list to reflect changes
        await _fetchUsers();
      } else {
        print("Failed to toggle admin status: ${response.body}");
        // Optionally, show an error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to toggle admin status. Please try again later.'),
          ),
        );
      }
    } catch (err) {
      print("Error toggling admin status: $err");
      // Optionally, show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error toggling admin status: $err'),
        ),
      );
    }
  }
  Widget _buildUsersTab() {
    final searchLower = _userSearch.toLowerCase();
    // Filter in-memory
    final filtered = _users.where((u) {
      final fName = (u['first_name'] ?? '').toString().toLowerCase();
      final lName = (u['last_name'] ?? '').toString().toLowerCase();
      final phone = (u['phone_number'] ?? '').toString().toLowerCase();
      final userId = (u['user_id'] ?? '').toString().toLowerCase();
      return fName.contains(searchLower) ||
          lName.contains(searchLower) ||
          phone.contains(searchLower) ||
          userId.contains(searchLower);
    }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            onChanged: (val) => setState(() => _userSearch = val),
            decoration: const InputDecoration(
              labelText: "Search users",
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingUsers
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final user = filtered[index];
              final userId = user['user_id'];
              final name =
              "${user['first_name']} ${user['last_name']}".trim();
              final phone = user['phone_number'] ?? '';
              final isAdmin = user['is_admin'] == true ||
                  user['is_admin'] == 1;

              return ListTile(
                title: Text(name),
                subtitle: Text("Phone: $phone\nID: $userId"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Toggle Admin Button
                    IconButton(
                      icon: Icon(
                        isAdmin
                            ? Icons.admin_panel_settings
                            : Icons.admin_panel_settings_outlined,
                        color: isAdmin ? Colors.green : Colors.grey,
                      ),
                      tooltip: isAdmin
                          ? 'Demote to User'
                          : 'Promote to Admin',
                      onPressed: () => _toggleAdmin(userId, isAdmin),
                    ),
                    // Delete Button
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete User',
                      onPressed: () => _deleteUser(userId),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserDetailsPage(userData: user),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // CALLS
  // ------------------------------------------------------------------
  Future<void> _fetchCalls() async {
    setState(() => _isLoadingCalls = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/phone-calls'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _calls = data;
          _isLoadingCalls = false;
        });
        print("Fetched ${data.length} phone calls");
      } else {
        setState(() => _isLoadingCalls = false);
        print("Error fetching calls: ${response.body}");
      }
    } catch (err) {
      setState(() => _isLoadingCalls = false);
      print("Exception phone calls: $err");
    }
  }

  Future<void> _deleteCall(String callId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final resp = await http.delete(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/phone-calls/$callId'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (resp.statusCode == 200) {
        setState(() {
          _calls.removeWhere((c) => c['call_id'] == callId);
        });
      } else {
        print("Failed to delete call: ${resp.body}");
      }
    } catch (err) {
      print("Error deleting call: $err");
    }
  }

  Widget _buildPhoneCallsTab() {
    final searchLower = _callSearch.toLowerCase();
    final filtered = _calls.where((c) {
      final from = (c['caller_phone'] ?? '').toString().toLowerCase();
      final to = (c['recipient_phone'] ?? '').toString().toLowerCase();
      final summary = (c['summary'] ?? '').toString().toLowerCase();
      return from.contains(searchLower) ||
          to.contains(searchLower) ||
          summary.contains(searchLower);
    }).toList();

    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            onChanged: (val) => setState(() => _callSearch = val),
            decoration: const InputDecoration(
              labelText: "Search calls",
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingCalls
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final call = filtered[index];
              final callId = call['call_id'];
              final summary = call['summary'] ?? '';
              final from = call['caller_phone'] ?? '';
              final to = call['recipient_phone'] ?? '';
              return ListTile(
                title: Text("Call #$callId - $summary"),
                subtitle: Text("From: $from / To: $to"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteCall(callId),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhoneCallDetailsPage(callData: call),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // CHATS
  // ------------------------------------------------------------------
  Future<void> _fetchChats() async {
    setState(() => _isLoadingChats = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/chats'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _chats = data;
          _isLoadingChats = false;
        });
        print("Fetched ${data.length} chats");
      } else {
        setState(() => _isLoadingChats = false);
        print("Error fetching chats: ${response.body}");
      }
    } catch (err) {
      setState(() => _isLoadingChats = false);
      print("Error chats: $err");
    }
  }

  Widget _buildChatsTab() {
    final sLower = _chatSearch.toLowerCase();
    final filtered = _chats.where((chat) {
      final cId = (chat['chat_id'] ?? '').toString().toLowerCase();
      final uId = (chat['user_id'] ?? '').toString().toLowerCase();
      final agentId = (chat['agent_id'] ?? '').toString().toLowerCase();
      return cId.contains(sLower) || uId.contains(sLower) || agentId.contains(sLower);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            onChanged: (val) => setState(() => _chatSearch = val),
            decoration: const InputDecoration(
              labelText: "Search chats",
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingChats
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final chat = filtered[index];
              final chatId = chat['chat_id'];
              final userId = chat['user_id'] ?? '';
              final agentId = chat['agent_id'] ?? '';
              // Convert userId -> "FName LName"
              final userName = _getUserDisplayName(userId);

              return ListTile(
                title: Text("Chat #$chatId"),
                subtitle: Text("User: $userName | Agent: $agentId"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatDetailsPage(chatData: chat),
                    ),
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () {
                    // Jump to user details
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserDetailsPage(
                          userData: {'user_id': userId},
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // TASKS
  // ------------------------------------------------------------------
  Future<void> _fetchTasks() async {
    setState(() => _isLoadingTasks = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/tasks'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _tasks = data;
          _isLoadingTasks = false;
        });
        print("Fetched ${data.length} tasks");
      } else {
        setState(() => _isLoadingTasks = false);
        print("Error fetching tasks: ${response.body}");
      }
    } catch (err) {
      setState(() => _isLoadingTasks = false);
      print("Error tasks: $err");
    }
  }

  Widget _buildTasksTab() {
    if (_isLoadingTasks) {
      return const Center(child: CircularProgressIndicator());
    }

    final searchLower = _taskSearch.toLowerCase();
    final filtered = _tasks.where((t) {
      final txt = (t['task_text'] ?? '').toString().toLowerCase();
      final st = (t['task_status'] ?? '').toString().toLowerCase();
      final cid = (t['client_id'] ?? '').toString().toLowerCase();
      return txt.contains(searchLower) || st.contains(searchLower) || cid.contains(searchLower);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            onChanged: (val) => setState(() => _taskSearch = val),
            decoration: const InputDecoration(
              labelText: "Search tasks",
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final task = filtered[index];
              final tId = task['task_id'];
              final tStatus = task['task_status'];
              final tText = task['task_text'] ?? "";
              final clientId = task['client_id'] ?? "unknown";
              // Convert userId -> user display name
              final userName = _getUserDisplayName(clientId);

              return ListTile(
                title: Text("Task #$tId - $tStatus"),
                subtitle: Text("User: $userName\n$tText"),
                trailing: IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserDetailsPage(
                          userData: {'user_id': clientId},
                        ),
                      ),
                    );
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TaskDetailsPage(taskData: task),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // AGENTS
  // ------------------------------------------------------------------
  Future<void> _fetchAgents() async {
    setState(() => _isLoadingAgents = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/agents'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _agents = data;
          _isLoadingAgents = false;
        });
        print("Fetched ${data.length} agents from server");
      } else {
        setState(() => _isLoadingAgents = false);
        print("Error fetching agents: ${response.body}");
      }
    } catch (err) {
      setState(() => _isLoadingAgents = false);
      print("Exception fetching agents: $err");
    }
  }

  Widget _buildAgentsTab() {
    final searchLower = _agentsSearch.toLowerCase();
    final filtered = _agents.where((agent) {
      final agId = (agent['agent_id'] ?? '').toString().toLowerCase();
      final clientId = (agent['client_id'] ?? '').toString().toLowerCase();
      final agName = (agent['agent_name'] ?? '').toString().toLowerCase();
      return agId.contains(searchLower) ||
          clientId.contains(searchLower) ||
          agName.contains(searchLower);
    }).toList();

    return Column(
      children: [
        // Search box
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            onChanged: (val) => setState(() => _agentsSearch = val),
            decoration: const InputDecoration(
              labelText: "Search agents",
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingAgents
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final agent = filtered[index];
              final agentId = agent['agent_id'];
              final clientId = agent['client_id'];
              final name = agent['agent_name'] ?? '';
              final chosen = agent['chosen'] == true;

              // Convert userId -> name
              final userName = _getUserDisplayName(clientId);

              return ListTile(
                title: Text("Agent #$agentId | Name: $name"),
                subtitle: Text("User: $userName\nchosen: $chosen"),
                onTap: () {
                  // Could navigate to AgentDetailsPage
                },
                trailing: IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () {
                    // jump to user details
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserDetailsPage(
                          userData: {'user_id': clientId},
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final translationProvider =
    Provider.of<TranslationProvider>(context, listen: true);
    final user = Provider.of<AuthProvider>(context).user;

    print("AdminPanelPage => user: $user");
    final bool isAdmin = _isUserAdmin(user);

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(translationProvider.t("Admin Panel"))),
        body: Center(
          child: Text(
            "You are not admin. 'is_admin' = ${user?['is_admin']} ",
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: "Prompts"),
            Tab(text: "Users"),
            Tab(text: "Calls"),
            Tab(text: "Chats"),
            Tab(text: "Tasks"),
            Tab(text: "Agents"),
          ],
        ),
      ),
      drawer: buildDrawer(context),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 0: Prompts
          _buildPromptsTab(),
          // 1: Users
          _buildUsersTab(),
          // 2: Calls
          _buildPhoneCallsTab(),
          // 3: Chats
          _buildChatsTab(),
          // 4: Tasks
          _buildTasksTab(),
          // 5: Agents
          _buildAgentsTab(),
        ],
      ),
    );
  }
}

// --------------------------- Sub-Pages for Details ----------------------------

// User details page
class UserDetailsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const UserDetailsPage({Key? key, required this.userData}) : super(key: key);

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  bool _isLoadingExtras = false;
  List<dynamic> _userCalls = [];
  List<dynamic> _userTasks = [];
  List<dynamic> _userChats = [];

  @override
  void initState() {
    super.initState();
    _fetchUserExtras();
  }

  Future<void> _fetchUserExtras() async {
    setState(() => _isLoadingExtras = true);

    final userId = widget.userData['user_id'];
    final baseUrl = 'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/';
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final headers = {
        'Authorization': 'Bearer ${authProvider.token}',
        'Content-Type': 'application/json',
      };

      // calls
      final callsResp = await http.get(
        Uri.parse('$baseUrl$userId/calls'),
        headers: headers,
      );
      if (callsResp.statusCode == 200) {
        _userCalls = jsonDecode(callsResp.body) ?? [];
      } else {
        print("Fetch calls error: ${callsResp.body}");
      }

      // tasks
      final tasksResp = await http.get(
        Uri.parse('$baseUrl$userId/tasks'),
        headers: headers,
      );
      if (tasksResp.statusCode == 200) {
        _userTasks = jsonDecode(tasksResp.body) ?? [];
      } else {
        print("Fetch tasks error: ${tasksResp.body}");
      }

      // chats
      final chatsResp = await http.get(
        Uri.parse('$baseUrl$userId/chats'),
        headers: headers,
      );
      if (chatsResp.statusCode == 200) {
        _userChats = jsonDecode(chatsResp.body) ?? [];
      } else {
        print("Fetch chats error: ${chatsResp.body}");
      }
    } catch (err) {
      print("Error fetching user extras: $err");
    }

    setState(() => _isLoadingExtras = false);
  }

  @override
  Widget build(BuildContext context) {
    final fName = widget.userData['first_name'] ?? '';
    final lName = widget.userData['last_name'] ?? '';
    final name = "$fName $lName".trim();
    final phone = widget.userData['phone_number'] ?? '';
    final country = widget.userData['country'] ?? '';
    final is_admin = widget.userData['is_admin'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text("User: $name")),
      body: _isLoadingExtras
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text("Name: $name",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          Text("Phone: $phone", style: const TextStyle(fontSize: 16)),
          Text("Country: $country", style: const TextStyle(fontSize: 16)),
          Text("User is ${is_admin ? 'admin' : 'not an admin'}.", style: const TextStyle(fontSize: 16)),
          const Divider(),
          _buildCallsSection(),
          const Divider(),
          _buildTasksSection(),
          const Divider(),
          _buildChatsSection(),
        ],
      ),
    );
  }

  Widget _buildCallsSection() {
    return ExpansionTile(
      title: Text("Calls (${_userCalls.length})"),
      children: _userCalls.isEmpty
          ? [
        const ListTile(
          title: Text("No calls found for this user."),
        )
      ]
          : _userCalls.map((call) {
        final callId = call['call_id'];
        final summary = call['summary'] ?? '';
        return ListTile(
          title: Text("Call #$callId"),
          subtitle:
          Text(summary.isNotEmpty ? summary : "No summary"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PhoneCallDetailsPage(callData: call),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildTasksSection() {
    return ExpansionTile(
      title: Text("Tasks (${_userTasks.length})"),
      children: _userTasks.isEmpty
          ? [
        const ListTile(
          title: Text("No tasks found for this user."),
        )
      ]
          : _userTasks.map((task) {
        final tId = task['task_id'];
        final tStatus = task['task_status'];
        return ListTile(
          title: Text("Task #$tId - $tStatus"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TaskDetailsPage(taskData: task),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildChatsSection() {
    return ExpansionTile(
      title: Text("Chats (${_userChats.length})"),
      children: _userChats.isEmpty
          ? [
        const ListTile(
          title: Text("No chats found for this user."),
        )
      ]
          : _userChats.map((chat) {
        final cId = chat['chat_id'];
        return ListTile(
          title: Text("Chat #$cId"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatDetailsPage(chatData: chat),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

// 2) Phone Call details
class PhoneCallDetailsPage extends StatefulWidget {
  final Map<String, dynamic> callData;
  const PhoneCallDetailsPage({Key? key, required this.callData}) : super(key: key);

  @override
  State<PhoneCallDetailsPage> createState() => _PhoneCallDetailsPageState();
}

class _PhoneCallDetailsPageState extends State<PhoneCallDetailsPage> {
  Map<String, dynamic>? _maybeUserRecipient;
  Map<String, dynamic>? _maybeUserCaller;

  @override
  void initState() {
    super.initState();
    _lookupUserByPhone(widget.callData['recipient_phone'] ?? '').then((u) {
      setState(() => _maybeUserRecipient = u);
    });
    _lookupUserByPhone(widget.callData['caller_phone'] ?? '').then((u) {
      setState(() => _maybeUserCaller = u);
    });
  }

  Future<Map<String, dynamic>?> _lookupUserByPhone(String phone) async {
    if (phone.isEmpty) return null;
    try {
      final resp = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/by-phone/$phone'),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data;
      }
    } catch (err) {
      print("Error looking up user by phone: $err");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.callData;
    final callId = call['call_id'];
    final summary = call['summary'] ?? '';
    final from = call['caller_phone'] ?? '';
    final to = call['recipient_phone'] ?? '';
    final transcript = call['transcript'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text("Call #$callId")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text("Call #$callId",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text("Summary: $summary", style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text("From: $from"),
          if (_maybeUserCaller != null)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        UserDetailsPage(userData: _maybeUserCaller!),
                  ),
                );
              },
              child: Text("View user with phone $from"),
            ),
          Text("To: $to"),
          if (_maybeUserRecipient != null)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        UserDetailsPage(userData: _maybeUserRecipient!),
                  ),
                );
              },
              child: Text("View user with phone $to"),
            ),
          const Divider(),
          Text("Transcript:",
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(transcript.isNotEmpty ? transcript : "No transcript"),
        ],
      ),
    );
  }
}

// 3) Chat details page
class ChatDetailsPage extends StatefulWidget {
  final Map<String, dynamic> chatData;
  const ChatDetailsPage({Key? key, required this.chatData}) : super(key: key);

  @override
  State<ChatDetailsPage> createState() => _ChatDetailsPageState();
}

class _ChatDetailsPageState extends State<ChatDetailsPage> {
  bool _isLoading = false;
  List<dynamic> _messages = [];

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    setState(() => _isLoading = true);
    final cId = widget.chatData['chat_id'];
    try {
      final resp = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/chat-messages/chat/$cId'),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          _messages = data;
          _isLoading = false;
        });
        print("Fetched ${data.length} messages for chat $cId");
      } else {
        setState(() => _isLoading = false);
        print("Error fetching chat messages: ${resp.body}");
      }
    } catch (err) {
      setState(() => _isLoading = false);
      print("Error: $err");
    }
  }

  @override
  Widget build(BuildContext context) {
    final cId = widget.chatData['chat_id'];
    final userId = widget.chatData['user_id'];

    return Scaffold(
      appBar: AppBar(title: Text("Chat #$cId")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
          ? const Center(child: Text("No messages in this chat."))
          : ListView.builder(
        // This ListView is scrollable by default for long chats
        itemCount: _messages.length,
        itemBuilder: (ctx, i) {
          final msg = _messages[i];
          final sender = msg['sender_type'] ?? 'unknown';
          final content = msg['content'] ?? '';
          return ListTile(
            title: Text("$sender: $content"),
          );
        },
      ),
    );
  }
}

// 4) Task details page
class TaskDetailsPage extends StatelessWidget {
  final Map<String, dynamic> taskData;
  const TaskDetailsPage({Key? key, required this.taskData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tId = taskData['task_id'];
    final tStatus = taskData['task_status'];
    final tText = taskData['task_text'] ?? '';
    final tPrompt = taskData['task_prompt'] ?? '';
    final summary = taskData['summary'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text("Task #$tId")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text("Task #$tId", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text("Status: $tStatus"),
          const Divider(),
          Text("Task Text:", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(tText.isNotEmpty ? tText : "No content"),
          const Divider(),
          Text("Task Prompt:", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(tPrompt.isNotEmpty ? tPrompt : "No prompt"),
          const Divider(),
          Text("Summary:", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(summary.isNotEmpty ? summary : "No summary"),
        ],
      ),
    );
  }
}
