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

  final String currentVersion = '1.3.0';
  Map<String, String>? _updateInfo;
  bool _isUpdateChecked = false;

  List<dynamic> _data = [];
  List<dynamic> _statsdata = [];
  Timer? _timer;

  FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
  Map<String, Set<String>> notifiedEventIds = {};
  Set<int> sentNotificationIds = {};
  bool _isLiveOnly = false;

  int _selectedIndex = 0;
  int _selectedTabIndex = 0;
  String _selectedType = 'Enter';
  String _selectedDays = '30';
  String _selectedLimit = '10';

  String defaultStats =
      'getLeaderboard?category=nether&type=count&days=30&limit=10';

  @override
  void initState() {
    super.initState();
    startForegroundService();
    fetchData();
    fetchStatsData(defaultStats);
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

  Future<void> fetchStatsData(String endpoint) async {
    try {
      final response =
          await http.get(Uri.parse('https://paceman.gg/stats/api/$endpoint'));

      if (response.statusCode == 200) {
        setState(() {
          _statsdata = json.decode(response.body);
        });
        log('Stats Data fetched successfully: ${_statsdata.length} items.');
        log('send point: ${endpoint}');
      } else {
        throw Exception('Failed to load stats data');
      }
    } catch (e) {
      log('Error fetching stats data: $e');
    }
  }

  String formatTime(int time, {bool includeDecimal = false}) {
    int seconds = time ~/ 1000;
    int milliseconds = time % 1000;

    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;

    int decimalPart = (milliseconds ~/ 100) % 10;

    if (includeDecimal) {
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}.$decimalPart';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
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

  final Map<String, int> eventPriority = {
    'rsg.credits': 1,
    'rsg.enter_end': 2,
    'rsg.enter_stronghold': 3,
    'rsg.first_portal': 4,
    'rsg.enter_fortress': 5,
    'rsg.enter_bastion': 6,
    'rsg.enter_nether': 7,
  };

  final List<String> _tabs = [
    'Nether',
    'Structure 1',
    'Structure 2',
    'First Portals',
    'Stronghold',
    'End',
    'Completion',
  ];

  final List<String> _tabImages = [
    'assets/icons/nether.png',
    'assets/icons/bastion.png',
    'assets/icons/fortress.png',
    'assets/icons/portal.png',
    'assets/icons/sh.png',
    'assets/icons/end.png',
    'assets/icons/credits.png',
  ];

  void _fetchDataForCurrentTab(int index) {
    String category = '';

    switch (index) {
      case 0:
        category = 'nether';
        break;
      case 1:
        category = 'first_structure';
        break;
      case 2:
        category = 'second_structure';
        break;
      case 3:
        category = 'first_portal';
        break;
      case 4:
        category = 'stronghold';
        break;
      case 5:
        category = 'end';
        break;
      case 6:
        category = 'finish';
        break;
      default:
        category = 'nether';
    }

    String daysValue;
    switch (_selectedDays) {
      case '1':
        daysValue = '1';
        break;
      case '7':
        daysValue = '7';
        break;
      case '30':
        daysValue = '30';
        break;
      case '9999':
        daysValue = '9999';
        break;
      default:
        daysValue = '30';
    }

    String limitValue;
    switch (_selectedLimit) {
      case '10':
        limitValue = '10';
        break;
      case '30':
        limitValue = '30';
        break;
      default:
        limitValue = '10';
    }

    fetchStatsData(
        'getLeaderboard?category=$category&type=${_selectedType == 'Qty' ? 'count' : _selectedType.toLowerCase()}&days=$daysValue&limit=$limitValue');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: DefaultTabController(
          length: _tabs.length,
          child: Column(
            children: [
              if (_selectedIndex == 1)
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        DropdownButton<String>(
                          value: _tabs[_selectedTabIndex],
                          items: List.generate(_tabs.length, (index) {
                            return DropdownMenuItem<String>(
                              value: _tabs[index],
                              child: Row(
                                children: [
                                  Image.asset(
                                    _tabImages[index],
                                    height: 24,
                                    width: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(_tabs[index]),
                                ],
                              ),
                            );
                          }),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedTabIndex = _tabs.indexOf(newValue!);
                              _fetchDataForCurrentTab(_selectedTabIndex);
                            });
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        DropdownButton<String>(
                          value: _selectedType,
                          items: [
                            'Enter',
                            'Average',
                            'Fastest',
                          ].map((String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(
                                type,
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedType = newValue!;
                              _fetchDataForCurrentTab(_selectedTabIndex);
                            });
                          },
                        ),
                        DropdownButton<String>(
                          value: _selectedDays,
                          items: [
                            '1',
                            '7',
                            '30',
                            '9999',
                          ].map((String day) {
                            return DropdownMenuItem<String>(
                              value: day,
                              child: Text(
                                day == '1'
                                    ? '24 hours'
                                    : day == '7'
                                        ? '7 days'
                                        : day == '30'
                                            ? '30 days'
                                            : 'Lifetime',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedDays = newValue!;
                              _fetchDataForCurrentTab(_selectedTabIndex);
                            });
                          },
                        ),
                        DropdownButton<String>(
                          value: _selectedLimit,
                          items: [
                            '10',
                            '30',
                          ].map((String limit) {
                            return DropdownMenuItem<String>(
                              value: limit,
                              child: Text(
                                limit == '10' ? 'TOP 10' : 'TOP 30',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedLimit = newValue!;
                              _fetchDataForCurrentTab(_selectedTabIndex);
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              Expanded(
                child: _selectedIndex == 0
                    ? _buildCurrentPaceView()
                    : _selectedIndex == 1
                        ? _buildStatsView()
                        : _buildSettingsView(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run),
            label: 'Current Pace',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildCurrentPaceView() {
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
                              final filteredData = _data.where((item) {
                                final liveAccount = item['user']['liveAccount'];
                                final isHidden = item['isHidden'] ?? false;
                                final isCheated = item['isCheated'] ?? false;
                                return (!_isLiveOnly || liveAccount != null) &&
                                    !isHidden &&
                                    !isCheated;
                              }).toList();

                              if (filteredData.isEmpty) {
                                return const Center(
                                  child: Text('No one is currently on pace...'),
                                );
                              }

                              final prioritizedItems = filteredData.map((item) {
                                final eventList =
                                    item['eventList'] as List<dynamic>?;

                                String? highestEvent;
                                int? highestIgt;

                                if (eventList != null) {
                                  for (var event in eventList) {
                                    String eventId = event['eventId'];
                                    int eventIgt = event['igt'];

                                    if (eventPriority.containsKey(eventId)) {
                                      if ((highestEvent == null ||
                                              eventPriority[eventId]! <
                                                  eventPriority[
                                                      highestEvent]!) ||
                                          (eventId == highestEvent &&
                                              eventIgt < highestIgt!)) {
                                        highestEvent = eventId;
                                        highestIgt = eventIgt;
                                      }
                                    }
                                  }
                                }

                                return {
                                  'item': item,
                                  'highestEvent': highestEvent,
                                  'highestIgt': highestIgt,
                                };
                              }).toList();

                              prioritizedItems.sort((a, b) {
                                final priorityA =
                                    eventPriority[a['highestEvent']] ??
                                        double.infinity;
                                final priorityB =
                                    eventPriority[b['highestEvent']] ??
                                        double.infinity;

                                if (priorityA == priorityB) {
                                  return (a['highestIgt'] ?? double.infinity)
                                      .compareTo(
                                          b['highestIgt'] ?? double.infinity);
                                }

                                return priorityA.compareTo(priorityB);
                              });

                              return ListView.builder(
                                itemCount: prioritizedItems.length,
                                itemBuilder: (context, index) {
                                  var data = prioritizedItems[index];
                                  var item = data['item'];
                                  final itemData =
                                      item['itemData']?['estimatedCounts'];
                                  var highestEvent = data['highestEvent'];
                                  var highestIgt = data['highestIgt'];

                                  final liveAccount =
                                      item['user']['liveAccount'];

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
                                                color: Colors.grey,
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
                                                      ),
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

  Widget _buildStatsView() {
    if (_statsdata.isEmpty) {
      return const Center(
        child: Text('No stats available'),
      );
    }

    return ListView.builder(
      itemCount: _statsdata.length,
      itemBuilder: (context, index) {
        final statsItem = _statsdata[index];

        final int qtyValue = statsItem['qty'];
        final int avgValue = statsItem['avg'].floor();
        final formattedTime = formatTime(avgValue, includeDecimal: true);

        final String selectedType = _selectedType;

        final Color qtyColor =
            (selectedType == 'Average' || selectedType == 'Fastest')
                ? Colors.grey
                : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black);

        final Color avgColor = (selectedType == 'Enter')
            ? Colors.grey
            : (Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black);

        final String playerName = statsItem['name'] ?? 'No Name';
        final String playerUrl = 'https://paceman.gg/stats/player/$playerName';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          elevation: 4,
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.all(16),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    launchUrl(Uri.parse(playerUrl));
                  },
                  child: Text(
                    '${index + 1}. $playerName',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$qtyValue',
                      style: TextStyle(
                        color: qtyColor,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      formattedTime,
                      style: TextStyle(
                        color: avgColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'There is nothing hrere yet :(',
          ),
          Text(
            'v$currentVersion',
          ),
        ],
      ),
    );
  }
}
