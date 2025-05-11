import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';
import 'task_details_page.dart';

// Bridging shapes
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    final halfWidth = size.width / 2;
    path.moveTo(halfWidth, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) => false;
}

class _BigTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final halfHeight = size.height / 2;
    final halfWidth  = size.width / 2;

    final bottomVertex = Offset(halfWidth, halfHeight + 68);
    final leftVertex   = Offset(halfWidth - 50, halfHeight + 19);
    final rightVertex  = Offset(halfWidth + 50, halfHeight + 19);

    final fillPaint = Paint()
      ..color = const Color(0xFFF9FBFE)
      ..style = PaintingStyle.fill;

    final fillPath = Path()
      ..moveTo(bottomVertex.dx, bottomVertex.dy)
      ..lineTo(leftVertex.dx, leftVertex.dy)
      ..lineTo(rightVertex.dx, rightVertex.dy)
      ..close();
    canvas.drawPath(fillPath, fillPaint);

    // left stroke
    final leftSidePath = Path()
      ..moveTo(bottomVertex.dx, bottomVertex.dy)
      ..lineTo(leftVertex.dx, leftVertex.dy);
    final leftSidePaint = Paint()
      ..color = Colors.indigo.shade300
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(leftSidePath, leftSidePaint);

    // right stroke
    final rightSidePath = Path()
      ..moveTo(bottomVertex.dx, bottomVertex.dy)
      ..lineTo(rightVertex.dx, rightVertex.dy);
    final rightSidePaint = Paint()
      ..color = Colors.indigo.shade300
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(rightSidePath, rightSidePaint);
  }

  @override
  bool shouldRepaint(_BigTrianglePainter oldDelegate) => false;
}

class TasksPage extends StatefulWidget {
  const TasksPage({Key? key}) : super(key: key);

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  bool _isLoading = true;
  List<dynamic> _allTasks = [];
  List<dynamic> _filteredTasks = [];
  String _searchQuery = '';
  bool _hasFetchedLanguage = false;

  // The currently selected status
  String _selectedStatus = 'in_progress'; // or 'pending', etc.

  int _selectedIndex = 3; // for bottom nav

  @override
  void initState() {
    super.initState();
    _fetchTasks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final translationProvider =
      Provider.of<TranslationProvider>(context, listen: false);
      final token = authProvider.token ?? "";
      final user = authProvider.user;
      if (!_hasFetchedLanguage && token.isNotEmpty && user != null) {
        // Call fetchUserLanguage only once per page open
        translationProvider.fetchUserLanguage(token, user['user_id']).catchError((error) {
          print("Error fetching language: $error");
        });
        _hasFetchedLanguage = true;
      }
    });
  }

  // Bottom nav
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/main');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/logs');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/chat');
        break;
      case 3:
        break; // already here
      case 4:
        Navigator.pushReplacementNamed(context, '/settings');
        break;
    }
  }

  Future<void> _fetchTasks() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?['user_id'];
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _allTasks = [];
        _filteredTasks = [];
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId/tasks'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _allTasks = data;
          _filteredTasks = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _allTasks = [];
          _filteredTasks = [];
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _allTasks = [];
        _filteredTasks = [];
      });
    }
  }

  void _filterTasks(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  // A row of status buttons (Pending, In progress, Done, Failed)
  Widget _buildStatusButtons(BuildContext context) {
    final t = Provider.of<TranslationProvider>(context, listen: false);

    final statuses = [
      {'key': 'pending', 'label': t.t('Pending')},
      {'key': 'in_progress', 'label': t.t('In progress')},
      {'key': 'done', 'label': t.t('Done')},
      // {'key': 'failed', 'label': t.t('Failed')},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: statuses.map((status) {
          final isSelected = (status['key'] == _selectedStatus);
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: isSelected ? const Color(0xFFE8EDFF) : Colors.indigo,
                backgroundColor: isSelected ? Colors.indigo : const Color(0xFFE8EDFF),
                side: const BorderSide(
                  color: Colors.transparent,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                setState(() {
                  _selectedStatus = status['key']!;
                });
              },
              child: Text(
                status['label']!,
                style: const TextStyle(
                  fontFamily: 'DrukTextWideLCG',
                  fontSize: 10,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<TranslationProvider>(context, listen: true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final userId = user?['user_id'];


    // We'll filter tasks by status and also by the search query
    final visibleTasks = _filteredTasks.where((task) {
      final status = (task['task_status'] ?? '').toString().toLowerCase();
      if (status != _selectedStatus) return false;

      final text = (task['task_text'] ?? '').toString().toLowerCase();
      final summary = (task['summary'] ?? '').toString().toLowerCase();
      return text.contains(_searchQuery) || summary.contains(_searchQuery);
    }).toList();

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
          title: Text(
            t.t('TASKS').toUpperCase(),
            style: const TextStyle(
              fontFamily: 'DrukTextWideLCG',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          actions: const [
            // IconButton(
            //   icon: const Icon(Icons.add),
            //   color: Colors.indigo,
            //   onPressed: () {
            //     // Navigate to form page
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (_) => const CreateTaskPage()),
            //     );
            //   },
            // ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // Main content
              Positioned.fill(
                bottom: 60,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                  children: [
                    // Our status buttons row
                    const SizedBox(height: 10),
                    _buildStatusButtons(context),
                    const SizedBox(height: 10),

                    // Search
                    // Padding(
                    //   padding: const EdgeInsets.all(8.0),
                    //   child: TextField(
                    //     onChanged: _filterTasks,
                    //     decoration: InputDecoration(
                    //       labelText: t.t("Search tasks"),
                    //       prefixIcon: const Icon(Icons.search),
                    //       border: const OutlineInputBorder(),
                    //     ),
                    //   ),
                    // ),
                    // Show tasks for the chosen status
                    Expanded(
                      child: visibleTasks.isEmpty
                          ? Center(
                        child: Text('${t.t("No tasks for")} $_selectedStatus.'),
                      )
                          : ListView.builder(
                        itemCount: visibleTasks.length,
                        itemBuilder: (ctx, i) {
                          final task = visibleTasks[i];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TaskDetailsPage(task: task),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task['summary'] ?? t.t("No Task Summary"),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${t.t("Status")}: ${task["task_status"]}'),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom nav + bridging shapes + diamond
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.indigo.shade300, width: 1),
                        ),
                      ),
                      child: BottomAppBar(
                        shape: const CircularNotchedRectangle(),
                        notchMargin: 8.0,
                        color: Colors.white,
                        elevation: 8.0,
                        child: SizedBox(
                          height: 60,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(
                                iconSize: 30.0,
                                icon: const Icon(Icons.home_outlined),
                                color: _selectedIndex == 0 ? Colors.indigo : Colors.grey,
                                onPressed: () => _onItemTapped(0),
                              ),
                              IconButton(
                                iconSize: 30.0,
                                icon: const Icon(Icons.call_outlined),
                                color: _selectedIndex == 1 ? Colors.indigo : Colors.grey,
                                onPressed: () => _onItemTapped(1),
                              ),
                              const SizedBox(width: 48),
                              IconButton(
                                iconSize: 30.0,
                                icon: const Icon(Icons.fact_check_outlined),
                                color: _selectedIndex == 3 ? Colors.indigo : Colors.grey,
                                onPressed: () => _onItemTapped(3),
                              ),
                              IconButton(
                                iconSize: 30.0,
                                icon: const Icon(Icons.settings_outlined),
                                color: _selectedIndex == 4 ? Colors.indigo : Colors.grey,
                                onPressed: () => _onItemTapped(4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // White bridging shape
                    Positioned(
                      bottom: 48,
                      left: 0,
                      right: 0,
                      child: InkWell(
                        // onTap: () => _onItemTapped(2),
                        child: Center(
                          child: CustomPaint(
                            painter: _TrianglePainter(),
                            child: const SizedBox(width: 90, height: 70),
                          ),
                        ),
                      ),
                    ),

                    // Big extra triangle
                    Positioned(
                      bottom: 60,
                      left: 0,
                      right: 0,
                      child: InkWell(
                        // onTap: () => _onItemTapped(2),
                        child: Center(
                          child: CustomPaint(
                            painter: _BigTrianglePainter(),
                            child: const SizedBox(width: 110, height: 80),
                          ),
                        ),
                      ),
                    ),

                    // Diamond button w/ Chat Icon
                    Positioned(
                      bottom: 56,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Transform.rotate(
                          angle: math.pi / 4, // diamond shape
                          child: InkWell(
                            onTap: () => _onItemTapped(2),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.indigo.shade300,
                                  width: 1.0,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.transparent,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Transform.rotate(
                                angle: -math.pi / 4,
                                child: SvgPicture.asset(
                                  'assets/ChatIcon.svg',
                                  semanticsLabel: 'Chat Icon',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // AI-Chat label
                    Positioned(
                      bottom: 4,
                      left: 0,
                      right: 0,
                      child: InkWell(
                        // onTap: () => _onItemTapped(2),
                        child: Center(
                          child: Text(
                            t.t("AI-Chat"),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
