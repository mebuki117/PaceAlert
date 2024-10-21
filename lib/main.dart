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
      home: const Main(),
    );
  }
}

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  MainState createState() => MainState();
}

class MainState extends State<Main> {
  static const platform = MethodChannel('com.example.pace_alert/service');

  List<dynamic> _data = [];
  Timer? _timer;
  FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
  Map<String, Set<String>> notifiedEventIds = {};
  Set<int> sentNotificationIds = {};
  bool _isLiveOnly = false;
  final String currentVersion = '1.1.2';
  Map<String, String>? _updateInfo;
  bool _isUpdateChecked = false;

  @override
  void initState() {
    super.initState();
    startForegroundService();
    fetchData();
    _timer = Timer.periodic(const Duration(seconds: 20), (timer) {
      fetchData();
    });
    _checkForUpdate();
  }

  bool _isNewerVersion(String current, String latest) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < currentParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }

    return false;
  }

  Future<void> _checkForUpdate() async {
    final response = await http.get(Uri.parse(
        'https://raw.githubusercontent.com/mebuki117/PaceAlert/refs/heads/main/meta.json'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final String latestVersion = jsonData['latest'];
      final String latestDownloadLink = jsonData['latest_download'];

      if (_isNewerVersion(currentVersion, latestVersion)) {
        setState(() {
          _updateInfo = {
            'latest': latestVersion,
            'latest_download': latestDownloadLink,
          };
        });
      }
    }

    setState(() {
      _isUpdateChecked = true;
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

  List<String> getEventDisplayText(String eventId) {
    switch (eventId) {
      case 'rsg.credits':
        return ['Finish', 'assets/icons/credits.png'];
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
      body: SafeArea(
        child: Column(
          children: [
            if (_isUpdateChecked && _updateInfo != null)
              Container(
                width: double.infinity,
                color: Colors.amber,
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () {
                          launchUrl(
                              Uri.parse(_updateInfo!['latest_download']!));
                        },
                        child: Text(
                          'New update available: v${_updateInfo!['latest']}',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            AppBar(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
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
                  Text(
                    'v$currentVersion',
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
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
                        : Builder(
                            builder: (context) {
                              final gameVersionCheck = _data.any(
                                  (item) => item['gameVersion'] == '1.16.1');

                              if (!gameVersionCheck) {
                                return const Center(
                                  child: Text('No one is currently on pace...'),
                                );
                              }

                              final filteredData = _data.where((item) {
                                final liveAccount = item['user']['liveAccount'];
                                return !_isLiveOnly || liveAccount != null;
                              }).toList();

                              if (filteredData.isEmpty) {
                                return const Center(
                                  child: Text('No one is currently on pace...'),
                                );
                              }

                              return ListView.builder(
                                itemCount: filteredData.length,
                                itemBuilder: (context, index) {
                                  var item = filteredData[index];
                                  var eventList =
                                      item['eventList'] as List<dynamic>?;

                                  String? highestEvent;
                                  int? highestIgt;

                                  if (eventList != null) {
                                    for (var event in eventList) {
                                      String eventId = event['eventId'];
                                      int eventIgt = event['igt'];

                                      if (highestIgt == null ||
                                          eventIgt > highestIgt) {
                                        highestEvent = eventId;
                                        highestIgt = eventIgt;
                                      }
                                    }
                                  }

                                  final liveAccount =
                                      item['user']['liveAccount'];
                                  final itemData =
                                      item['itemData']?['estimatedCounts'];

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 16),
                                    elevation: 4,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      leading: highestEvent != null
                                          ? Image.asset(
                                              getEventDisplayText(
                                                  highestEvent)[1],
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
                                                  decoration:
                                                      TextDecoration.underline,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            )
                                          : Text(item['nickname'] ?? 'No Name'),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (highestEvent != null) ...[
                                            Text(
                                              getEventDisplayText(
                                                  highestEvent)[0],
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  formatTime(highestIgt!),
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    const SizedBox(width: 8),
                                                    if (itemData?[
                                                            'minecraft:ender_pearl'] !=
                                                        null) ...[
                                                      const SizedBox(width: 8),
                                                      Image.asset(
                                                        'assets/icons/ender_pearl.png',
                                                        width: 16,
                                                        height: 16,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        itemData[
                                                                'minecraft:ender_pearl']
                                                            .toString(),
                                                        style: const TextStyle(
                                                          color: Colors.grey,
                                                        ),
                                                      )
                                                    ],
                                                    if (itemData?[
                                                            'minecraft:blaze_rod'] !=
                                                        null) ...[
                                                      const SizedBox(width: 8),
                                                      Image.asset(
                                                        'assets/icons/blaze_rod.png',
                                                        width: 16,
                                                        height: 16,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        itemData[
                                                                'minecraft:blaze_rod']
                                                            .toString(),
                                                        style: const TextStyle(
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
