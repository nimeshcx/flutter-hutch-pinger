import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const PingerApp());

class PingerApp extends StatelessWidget {
  const PingerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Net Stabilizer',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: const Color(0xFF22c55e),
      ),
      home: const PingerHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PingerHomePage extends StatefulWidget {
  const PingerHomePage({super.key});

  @override
  State<PingerHomePage> createState() => _PingerHomePageState();
}

class _PingerHomePageState extends State<PingerHomePage> {
  final TextEditingController _urlController =
      TextEditingController(text: 'https://selfcare.hutch.lk');
  
  bool _isRunning = false;
  bool _batterySaver = true;
  String _intervalMode = '3000';
  
  int _currentPing = 0;
  int _averagePing = 0;
  int _failCount = 0;
  final List<int> _pingHistory = [];
  
  final List<String> _logs = [];
  Timer? _pingerTimer;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void dispose() {
    _pingerTimer?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  void _log(String msg, {bool isError = false}) {
    if (_batterySaver && !isError && _logs.length % 5 != 0) return; // RAM saver throttle
    setState(() {
      final time = DateTime.now().toIso8601String().split('T')[1].substring(0, 8);
      _logs.insert(0, '[$time] $msg');
      if (_logs.length > 40) _logs.removeLast();
    });
  }

  void _togglePinger() {
    if (_isRunning) {
      _stopPinger();
    } else {
      _startPinger();
    }
  }

  void _startPinger() {
    if (_urlController.text.trim().isEmpty) return;
    setState(() {
      _isRunning = true;
      _failCount = 0;
      _pingHistory.clear();
    });
    _log('Stabilizer started.');
    _executePing();
  }

  void _stopPinger() {
    _pingerTimer?.cancel();
    setState(() {
      _isRunning = false;
    });
    _log('Stabilizer stopped.');
  }

  Future<void> _executePing() async {
    if (!_isRunning) return;

    final urlStr = _urlController.text.trim();
    final uri = Uri.parse(urlStr.contains('?') ? '$urlStr&_t=${DateTime.now().millisecondsSinceEpoch}' : '$urlStr?_t=${DateTime.now().millisecondsSinceEpoch}');

    _stopwatch.reset();
    _stopwatch.start();

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      _stopwatch.stop();

      if (!_isRunning) return;
      
      final latency = _stopwatch.elapsedMilliseconds;
      _pingHistory.add(latency);
      if (_pingHistory.length > 20) _pingHistory.removeAt(0);

      final avg = (_pingHistory.reduce((a, b) => a + b) / _pingHistory.length).round();

      setState(() {
        _currentPing = latency;
        _averagePing = avg;
      });

      _log('Ping OK: ${latency}ms (Avg: ${avg}ms)');
    } catch (e) {
      _stopwatch.stop();
      if (!_isRunning) return;

      setState(() {
        _failCount++;
      });
      _log('Ping failed / Timeout', isError: true);
    }

    _scheduleNext();
  }

  void _scheduleNext() {
    if (!_isRunning) return;

    int delay = 3000;
    if (_intervalMode == '1000') delay = 1000;
    else if (_intervalMode == '5000') delay = 5000;
    else if (_intervalMode == 'RANDOM') {
      delay = 2000 + (DateTime.now().millisecond % 4000);
    }

    _pingerTimer = Timer(Duration(milliseconds: delay), _executePing);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FLUTTER_NET_STABILIZER', style: TextStyle(fontSize: 14, fontFamily: 'monospace')),
        backgroundColor: const Color(0xFF0e0e10),
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: _isRunning ? const Color(0xFF22c55e) : const Color(0xFF555555)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _isRunning ? 'ACTIVE' : 'IDLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: _isRunning ? const Color(0xFF22c55e) : const Color(0xFF88888c),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // STATS ROW
            Row(
              children: [
                _buildStatBox('CURRENT', '$_currentPing ms', Colors.white),
                const SizedBox(width: 6),
                _buildStatBox('AVERAGE', '$_averagePing ms', Colors.white),
                const SizedBox(width: 6),
                _buildStatBox('FAILED', '$_failCount', const Color(0xFFef4444)),
              ],
            ),
            const SizedBox(height: 10),

            // CONTROLS CARD
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0e0e10),
                border: Border.all(color: const Color(0xFF222226)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TARGET URL', style: TextStyle(fontSize: 10, color: Color(0xFF88888c), fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.all(10),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF222226))),
                      filled: true,
                      fillColor: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('PING INTERVAL', style: TextStyle(fontSize: 10, color: Color(0xFF88888c), fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _intervalMode,
                    dropdownColor: const Color(0xFF0e0e10),
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Colors.white),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF222226))),
                      filled: true,
                      fillColor: Colors.black,
                    ),
                    items: const [
                      DropdownMenuItem(value: '1000', child: Text('Fast (1.0s)')),
                      DropdownMenuItem(value: '3000', child: Text('Balanced (3.0s)')),
                      DropdownMenuItem(value: '5000', child: Text('Battery Saver (5.0s)')),
                      DropdownMenuItem(value: 'RANDOM', child: Text('Random (2s - 6s)')),
                    ],
                    onChanged: (val) => setState(() => _intervalMode = val ?? '3000'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: _batterySaver,
                        onChanged: (val) => setState(() => _batterySaver = val ?? true),
                      ),
                      const Text('Max Battery & RAM Saver', style: TextStyle(fontSize: 11, color: Color(0xFF88888c), fontFamily: 'monospace')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRunning ? const Color(0xFFef4444) : Colors.white,
                        foregroundColor: _isRunning ? Colors.white : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _togglePinger,
                      child: Text(
                        _isRunning ? 'STOP STABILIZER' : 'START STABILIZER',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // LOGS BOX
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0e0e10),
                  border: Border.all(color: const Color(0xFF222226)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LIVE EVENT LOG', style: TextStyle(fontSize: 10, color: Color(0xFF88888c), fontFamily: 'monospace')),
                    const Divider(color: Color(0xFF222226)),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Text(
                            _logs[index],
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: _logs[index].contains('failed') ? const Color(0xFFef4444) : const Color(0xFFA1A1AA),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color valColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0e0e10),
          border: Border.all(color: const Color(0xFF222226)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF88888c), fontFamily: 'monospace')),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valColor, fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}
