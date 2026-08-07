import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }
  runApp(const MoradTkApp());
}

class MoradTkApp extends StatelessWidget {
  const MoradTkApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MORAD_TK Smart Relay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardTheme(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({Key? key}) : super(key: key);

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  DatabaseReference? _dbRef;
  
  bool isOnline = false;
  bool isLocalConnected = false;
  String localDeviceIp = "192.168.1.50"; // افتراضي للشبكة المحلية

  List<Map<String, dynamic>> switches = List.generate(12, (index) => {
    "id": index,
    "name": "سويتش ${index + 1}",
    "state": false,
    "color": Colors.blueAccent.value,
    "timerStart": "00:00",
  });

  int analog34Value = 0; // خزان المياه (Pin 34)
  int analog35Value = 0; // جهد الشبكة (Pin 35)

  @override
  void initState() {
    super.initState();
    _initFirebase();
    _checkLocalConnection();
  }

  void _initFirebase() {
    try {
      _dbRef = FirebaseDatabase.instance.ref();
      
      _dbRef?.child('status/isOnline').onValue.listen((event) {
        if (mounted) {
          setState(() => isOnline = (event.snapshot.value as bool?) ?? false);
        }
      });

      _dbRef?.child('switches').onValue.listen((event) {
        if (event.snapshot.value != null && mounted) {
          List<dynamic> data = jsonDecode(jsonEncode(event.snapshot.value));
          setState(() {
            for (int i = 0; i < data.length && i < 12; i++) {
              switches[i]['state'] = data[i]['state'] ?? false;
              switches[i]['name'] = data[i]['name'] ?? "سويتش ${i + 1}";
            }
          });
        }
      });

      _dbRef?.child('inputs/pin34_tank').onValue.listen((event) {
        if (mounted) setState(() => analog34Value = (event.snapshot.value as int?) ?? 0);
      });

      _dbRef?.child('inputs/pin35_voltage').onValue.listen((event) {
        if (mounted) setState(() => analog35Value = (event.snapshot.value as int?) ?? 0);
      });
    } catch (e) {
      debugPrint("Firebase database listener error: $e");
    }
  }

  Future<void> _checkLocalConnection() async {
    try {
      final res = await http.get(Uri.parse('http://$localDeviceIp/api/status')).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200 && mounted) {
        setState(() => isLocalConnected = true);
      }
    } catch (_) {
      if (mounted) setState(() => isLocalConnected = false);
    }
  }

  void _toggleSwitch(int index) {
    bool newState = !switches[index]['state'];
    setState(() => switches[index]['state'] = newState);

    // تحديث السحابة
    _dbRef?.child('switches/$index/state').set(newState);

    // تحديث محلي إذا كانت اللوحة متاحة
    if (isLocalConnected) {
      http.post(
        Uri.parse('http://$localDeviceIp/api/switch'),
        body: jsonEncode({'id': index, 'state': newState}),
      ).catchError((_) {});
    }
  }

  void _openSettings(int index) {
    TextEditingController nameController = TextEditingController(text: switches[index]['name']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ضبط سويتش ${index + 1}'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'اسم السويتش'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              setState(() => switches[index]['name'] = nameController.text);
              _dbRef?.child('switches/$index/name').set(nameController.text);
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double voltage = (analog35Value / 4095.0) * 250.0;
    double tankPercent = (analog34Value / 4095.0).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MORAD_TK Control'),
        actions: [
          Icon(isLocalConnected ? Icons.wifi : Icons.wifi_off, color: isLocalConnected ? Colors.green : Colors.grey),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: CircleAvatar(radius: 6, backgroundColor: isOnline ? Colors.green : Colors.red),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text('خزان المياه (Pin 34)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Container(
                            height: 80,
                            width: 50,
                            decoration: BoxDecoration(border: Border.all(color: Colors.cyan), borderRadius: BorderRadius.circular(8)),
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                Container(height: 80 * tankPercent, color: Colors.cyan.withOpacity(0.5)),
                                Center(child: Text('${(tankPercent * 100).toInt()}%')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text('جهد الشبكة (Pin 35)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 15),
                          Text('${voltage.toStringAsFixed(1)} V', style: const TextStyle(fontSize: 22, color: Colors.amber, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(value: voltage / 250.0, color: Colors.amber),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: 12,
              itemBuilder: (ctx, i) {
                bool isOn = switches[i]['state'];
                return Card(
                  color: isOn ? Colors.blue.withOpacity(0.2) : const Color(0xFF1E1E1E),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.settings, size: 16),
                          onPressed: () => _openSettings(i),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.power_settings_new, size: 32, color: isOn ? Colors.greenAccent : Colors.grey),
                        onPressed: () => _toggleSwitch(i),
                      ),
                      Padding(
                        padding: const EdgeInsets.bottom(8),
                        child: Text(switches[i]['name'], style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
