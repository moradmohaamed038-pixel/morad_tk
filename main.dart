import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

void main() {
  runApp(const MoradTkApp());
}

class MoradTkApp extends StatelessWidget {
  const MoradTkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MORAD TK Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const AuthScreen(),
    );
  }
}

// 1. شاشة المصادقة (كلمة المرور)
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _passController = TextEditingController();
  final String correctPassword = "admin123"; // متوافقة مع كود ESP32
  bool _obscureText = true;

  void _login() {
    if (_passController.text == correctPassword) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ControlScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمة المرور غير صحيحة! (الافتراضية: admin123)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MORAD TK - تسجيل الدخول')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            TextField(
              controller: _passController,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.blueAccent,
              ),
              onPressed: _login,
              child: const Text('دخول للوحة التحكم', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// 2. شاشة التحكم الرئيسية المعتمدة على WebSocket
class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  // الاتصال عبر mDNS المعتمد في كود الـ ESP32
  late WebSocketChannel _channel;
  bool isConnected = false;

  List<bool> relayStates = List.generate(12, (index) => false);
  int waterLevelRaw = 0;
  int gridStatus = 0;
  
  // إعدادات السويتش والوقت مع تغيير اللون
  bool timerSwitch = false;
  Color switchColor = Colors.green;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      // الاتصال عبر منفذ الـ WebSocket رقم 81 المذكور في الكود
      _channel = WebSocketChannel.connect(Uri.parse('ws://morad-relay.local:81'));
      setState(() {
        isConnected = true;
      });

      // إرسال مصادقة وطلب الميتافيتا البيانات الحالية
      _channel.sink.add(json.encode({"auth": "admin123"}));
      _channel.sink.add(json.encode({"command": "GET_METADATA"}));

      _channel.stream.listen((message) {
        _parseIncomingData(message);
      }, onError: (error) {
        setState(() => isConnected = false);
      }, onDone: () {
        setState(() => isConnected = false);
      });
    } catch (e) {
      setState(() => isConnected = false);
    }
  }

  void _parseIncomingData(String message) {
    try {
      final data = json.decode(message);
      
      // إذا كان رد تحديث فردي لريليه معين
      if (data.containsKey('relay') && data.containsKey('state')) {
        int rIndex = data['relay'] - 1;
        int rState = data['state'];
        if (rIndex >= 0 && rIndex < 12) {
          setState(() {
            relayStates[rIndex] = (rState == 1);
          });
        }
      }
      
      // إذا كان رد جلب الميتافيتا الكاملة GET_METADATA
      if (data.containsKey('items')) {
        var items = data['items'] as List;
        setState(() {
          for (var item in items) {
            String id = item['id'];
            if (id == 'A34') {
              waterLevelRaw = item['rawValue'] ?? 0;
            } else if (id == 'l1') {
              gridStatus = item['state'] ?? 0;
            } else if (id.startsWith('v')) {
              int rIdx = int.parse(id.substring(1)) - 1;
              if (rIdx >= 0 && rIdx < 12) {
                relayStates[rIdx] = (item['state'] == 1);
              }
            }
          }
        });
      }
    } catch (e) {
      // خطأ في تحليل البيانات
    }
  }

  // إرسال أمر تبديل حالة الريليه للوحة
  void _toggleRelay(int index, bool value) {
    setState(() {
      relayStates[index] = value;
    });
    
    final command = {
      "relay": index + 1,
      "state": value ? 1 : 0
    };
    
    if (isConnected) {
      _channel.sink.add(json.encode(command));
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // حساب نسبة مئوية تقريبية لمستوى المياه بناءً على قراءة الحساس التناظري 0-4095
    int waterPercent = ((waterLevelRaw / 4095.0) * 100).clamp(0, 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: Text(isConnected ? 'MORAD TK (متصل محلياً)' : 'غير متصل باللوحة'),
        backgroundColor: isConnected ? Colors.green[800] : Colors.red[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _connectWebSocket,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AuthScreen()),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // قسم حالة الحساسات (مستوى الخزان + حالة الشبكة)
            Card(
              color: const Color(0xFF1E1E1E),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('مستوى خزان المياه (Pin 35)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('$waterPercent %', style: const TextStyle(fontSize: 16, color: Colors.blueAccent)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: waterPercent / 100,
                      minHeight: 15,
                      backgroundColor: Colors.grey[800],
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('حالة جهد الشبكة (Pin 34):', style: TextStyle(fontSize: 14)),
                        Chip(
                          label: Text(gridStatus == 1 ? 'مستقر (Active)' : 'مفصول (Off)'),
                          backgroundColor: gridStatus == 1 ? Colors.green[700] : Colors.grey[700],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // قسم إعداد الوقت والسويتش المتغير اللون
            Card(
              color: const Color(0xFF1E1E1E),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ضبط الوقت (تشغيل مجدول)', style: TextStyle(fontSize: 16)),
                    Switch(
                      value: timerSwitch,
                      activeColor: switchColor,
                      onChanged: (val) {
                        setState(() {
                          timerSwitch = val;
                          switchColor = val ? Colors.amber : Colors.green;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // شبكة الريليهات الـ 12 المطبقة بدقة حسب كود اللوحة
            const Text('التحكم بالريليهات (12 قناة)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: relayStates[index] ? Colors.green[700] : Colors.grey[800],
                  ),
                  onPressed: () => _toggleRelay(index, !relayStates[index]),
                  child: Text('ريليه ${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
