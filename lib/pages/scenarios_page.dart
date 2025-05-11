import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart';

import 'dart:math' as math;
import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';
import 'create_scenario_page.dart';
import 'edit_scenario_page.dart';


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


class ScenariosPage extends StatefulWidget {
  const ScenariosPage({Key? key}) : super(key: key);

  @override
  _ScenariosPageState createState() => _ScenariosPageState();
}

class _ScenariosPageState extends State<ScenariosPage> {
  bool _isLoading = true;
  List<dynamic> _scenarios = [];
  int _selectedIndex = 3; // for bottom nav

  @override
  void initState() {
    super.initState();
    _fetchScenarios();
  }  // Bottom nav
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


  Future<void> _fetchScenarios() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?['user_id'];
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final resp = await http.get(
      Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/getAll/$userId'),
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
    final bottomBarHeight = 60.0; // same as your BottomAppBar height
    final extraPadding = 16.0;    // gap between FAB and bottom bar
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('My Scenarios')),
        backgroundColor: const Color(0xFFE8EDFF),
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: _isLoading
            ? Stack(children: [const Center(child: CircularProgressIndicator()), Positioned(
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
        ),])
            : _scenarios.isEmpty
            ? Stack(children: [Center(child: Text(t.t('No scenarios found.'))), Positioned(
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
        ),])
            : Stack(children:[ListView.builder(
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
        ),Positioned(
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
        ),])
      ),
      // 1) Tell Scaffold to float at its end.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      // 2) Wrap in Padding to push it up above your manual bottom menu.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: bottomBarHeight + extraPadding + MediaQuery.of(context).padding.bottom,
          right: 16.0, // keep your usual side inset
        ),
        child: FloatingActionButton(
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
      ),
    );
  }
}
