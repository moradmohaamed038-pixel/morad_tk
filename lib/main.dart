import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SmartRelayApp());
}

class SmartRelayApp extends StatelessWidget {
  const SmartRelayApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Relay Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // حالات الريليهات (12 ريليه)
  List<bool> relayStates = List.generate(12, (_) => false);

  // قراءات المدخلات التناظرية (Pins 34 & 35)
  int analog34Value = 0;
  int analog35Value = 0;

  @override
  void initState() {
    super.initState();
    _listenToFirebase();
  }

  void _listenToFirebase() {
    // الاستماع لحالات الريليهات
    _dbRef.child('relays').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = List<dynamic>.from(event.snapshot.value as List);
        setState(() {
          relayStates = data.map((e) => e == true).toList();
        });
      }
    });

    // الاستماع لقراءات Pin 34 و Pin 35 فقط
    _dbRef.child('inputs/analog34').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          analog34Value = int.tryParse(event.snapshot.value.toString()) ?? 0;
        });
      }
    });

    _dbRef.child('inputs/analog35').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          analog35Value = int.tryParse(event.snapshot.value.toString()) ?? 0;
        });
      }
    });
  }

  // تبديل حالة الريليه في Firebase
  void _toggleRelay(int index) {
    bool newState = !relayStates[index];
    _dbRef.child('relays/$index').set(newState);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MORAD_TK - Smart Relay'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // قسم قراءات المدخلات التناظرية (Pins 34 & 35)
            const Text(
              'المدخلات التناظرية (Analog Inputs)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('Pin 34', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('$analog34Value', style: const TextStyle(fontSize: 22, color: Colors.blue)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('Pin 35', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('$analog35Value', style: const TextStyle(fontSize: 22, color: Colors.green)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // قسم التحكم بالريليهات
            const Text(
              'مفاتيح التحكم (Relay Controls)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
              itemCount: relayStates.length,
              itemBuilder: (context, index) {
                bool isOn = relayStates[index];
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOn ? Colors.green : Colors.grey.shade300,
                    foregroundColor: isOn ? Colors.white : Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _toggleRelay(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isOn ? Icons.power_settings_new : Icons.power_off,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text('Relay ${index + 1}'),
                      Text(
                        isOn ? 'ON' : 'OFF',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
