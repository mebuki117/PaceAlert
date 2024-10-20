import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:developer';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const platform = MethodChannel('com.example.pace_alert/service');

  List<dynamic> _data = [];
  Timer? _timer;
  FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
  Map<String, Set<String>> notifiedEventIds = {};
  Set<int> sentNotificationIds = {};
  bool _isLiveOnly = false;

  @override
  void initState() {
    super.initState();
    startForegroundService();
    fetchData();
    _timer = Timer.periodic(const Duration(seconds: 20), (timer) {
      fetchData();
    });
  }

  Future<void> startForegroundService() async {
    await platform.invokeMethod('startService');
  }

  Future<void> fetchData() async {
    try {
      final response =
          await http.get(Uri.parse('https://paceman.gg/api/ars/liveruns'));

      if (response.statusCode == 200) {
        setState(() {
          _data = json.decode(response.body);
        });
        log('Data fetched successfully: ${_data.length} items.');
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      log('Error fetching data: $e');
    }
  }

  String formatTime(int time) {
    int seconds = time ~/ 1000;

    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  final Map<String, int> eventPriority = {
    'rsg.enter_end': 1,
    'rsg.enter_stronghold': 2,
    'rsg.first_portal': 3,
    'rsg.enter_fortress': 4,
    'rsg.enter_bastion': 5,
    'rsg.enter_nether': 6,
    'rsg.credits': 7,
  };

  List<String> getEventDisplayText(String eventId) {
    switch (eventId) {
      case 'rsg.credits':
        return ['Credits', 'assets/icons/credits.png'];
      case 'rsg.enter_end':
        return ['Enter End', 'assets/icons/end.png'];
      case 'rsg.enter_stronghold':
        return ['Enter Stronghold', 'assets/icons/sh.png'];
      case 'rsg.first_portal':
        return ['First Portal', 'assets/icons/portal.png'];
      case 'rsg.enter_fortress':
        return ['Enter Fortress', 'assets/icons/fortress.png'];
      case 'rsg.enter_bastion':
        return ['Enter Bastion', 'assets/icons/bastion.png'];
      case 'rsg.enter_nether':
        return ['Enter Nether', 'assets/icons/nether.png'];
      default:
        return ['Unknown Event', 'assets/icons/paceman.png'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Current Pace'),
            const SizedBox(width: 8),
            Image.asset(
              'assets/icons/paceman.png',
              width: 24,
              height: 24,
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          SwitchListTile(
            title: const Text('Live Only'),
            value: _isLiveOnly,
            onChanged: (bool value) {
              setState(() {
                _isLiveOnly = value;
              });
            },
          ),
          Expanded(
            child: _data.isEmpty
                ? const Center(
                    child: Text('No one is currently on pace...'),
                  )
                : ListView.builder(
                    itemCount: _data.length,
                    itemBuilder: (context, index) {
                      var item = _data[index];
                      var eventList = item['eventList'] as List<dynamic>?;

                      String? highestPriorityEvent;
                      int? highestIgt;

                      if (eventList != null) {
                        for (var event in eventList) {
                          String eventId = event['eventId'];
                          int eventIgt = event['igt'];

                          if (eventPriority.containsKey(eventId)) {
                            if (highestPriorityEvent == null ||
                                eventPriority[eventId]! <
                                    eventPriority[highestPriorityEvent]!) {
                              highestPriorityEvent = eventId;
                              highestIgt = eventIgt;
                            }
                          }
                        }
                      }

                      final liveAccount = item['user']['liveAccount'];

                      if (_isLiveOnly && liveAccount == null) {
                        return Container();
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        elevation: 4,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: highestPriorityEvent != null
                              ? Image.asset(
                                  getEventDisplayText(highestPriorityEvent)[1],
                                  width: 24,
                                  height: 24,
                                )
                              : const Icon(Icons.access_time,
                                  color: Colors.blue),
                          title: liveAccount != null
                              ? GestureDetector(
                                  onTap: () {
                                    launchUrl(Uri.parse(
                                        'https://www.twitch.tv/$liveAccount'));
                                  },
                                  child: Text(
                                    item['nickname'] ?? 'No Name',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : Text(item['nickname'] ?? 'No Name'),
                          subtitle: highestPriorityEvent != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      getEventDisplayText(
                                          highestPriorityEvent)[0],
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      formatTime(highestIgt!),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text('No one is currently on pace...'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
