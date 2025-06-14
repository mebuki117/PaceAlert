import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:developer';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class MainState extends State<Main> with TickerProviderStateMixin {
  static const platform = MethodChannel('com.example.pace_alert/service');

  final String currentVersion = '1.6.1';
  Map<String, String>? _updateInfo;
  bool _isUpdateChecked = false;

  late TabController _statsTabController;
  late TabController _settingsTabController;

  List<dynamic> _data = [];
  List<dynamic> _statsdata = [];
  Map<String, dynamic> _userstatsdata = {};

  Timer? _timer;
  FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
  Map<String, Set<String>> notifiedEventIds = {};
  Set<int> sentNotificationIds = {};

  int _selectedIndex = 1;
  int _selectedTabIndex = 0;
  String _selectedType = 'Qty';
  String _selectedDays = '30';
  String _selectedLimit = '10';

  String defaultStats =
      'getLeaderboard?category=nether&type=count&days=30&limit=10';

  final TextEditingController _searchController = TextEditingController();

  String _searchAvgCV = 'Avg';
  String _searchDays = '720';
  bool _searchStructure = true;

  List<String> usernames = [];
  final TextEditingController usernameController = TextEditingController();
  String _filterType = 'No Filter';

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
    _statsTabController = TabController(length: 2, vsync: this);
    _settingsTabController = TabController(length: 2, vsync: this);
    _loadUsernames();
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

  Future<void> fetchStatsData(String endpoint,
      {bool isUserStats = false}) async {
    try {
      final response =
          await http.get(Uri.parse('https://paceman.gg/stats/api/$endpoint'));

      if (response.statusCode == 200) {
        setState(() {
          if (isUserStats) {
            _userstatsdata = json.decode(response.body);
            log('User Stats Data fetched successfully: ${_userstatsdata.length} items.');
          } else {
            _statsdata = json.decode(response.body);
            log('Stats Data fetched successfully: ${_statsdata.length} items.');
          }
        });
        log('end point: $endpoint');
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

  String _formatTimeWithoutLeadingZero(int value) {
    String formatted = formatTime(value, includeDecimal: true);

    final parts = formatted.split(':');
    final hours = parts[0].startsWith('0') ? parts[0].substring(1) : parts[0];
    final minutes = parts[1];

    return '$hours:$minutes';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statsTabController.dispose();
    _settingsTabController.dispose();
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
    'First Portal',
    'Stronghold',
    'End',
    'Finish',
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

  final Map<String, String> _statKeyDisplayNames = {
    'nether': 'Nether',
    'bastion': 'Bastion',
    'fortress': 'Fortress',
    'first_structure': 'First Structure',
    'second_structure': 'Second Structure',
    'first_portal': 'First Portal',
    'stronghold': 'Stronghold',
    'end': 'End',
    'finish': 'Finish',
  };

  void _fetchStatsData({required int index, bool isSessionData = false}) async {
    String category = '';

    if (!isSessionData) {
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

      String daysValue = _selectedDays == '1' ||
              _selectedDays == '7' ||
              _selectedDays == '30' ||
              _selectedDays == '9999'
          ? _selectedDays
          : '30';

      String limitValue = _selectedLimit == '10' || _selectedLimit == '30'
          ? _selectedLimit
          : '10';

      const snackBar = SnackBar(
        content: Text('Fetching data...'),
        duration: Duration(days: 365),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);

      await fetchStatsData(
          'getLeaderboard?category=$category&type=${_selectedType == 'Qty' ? 'count' : _selectedType.toLowerCase()}&days=$daysValue&limit=$limitValue');
    } else {
      const snackBar = SnackBar(
        content: Text('Fetching data...'),
        duration: Duration(days: 365),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);

      setState(() {
        _userstatsdata = {};
      });

      String user = _searchController.text;
      await fetchStatsData(
          'getSessionStats?name=$user&hours=$_searchDays&hoursBetween=$_searchDays',
          isUserStats: true);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  void _addUsername() async {
    final username = usernameController.text;
    if (username.isNotEmpty && !usernames.contains(username)) {
      setState(() {
        usernames.add(username);
      });
      usernameController.clear();
      _saveUsernames();
    } else if (usernames.contains(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This username is already added.')),
      );
    }
  }

  void _saveUsernames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('usernames', usernames);
  }

  void _loadUsernames() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      usernames = prefs.getStringList('usernames') ?? [];
      usernames.sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(
              toolbarHeight: kToolbarHeight - 56,
              bottom: TabBar(
                controller: _statsTabController,
                tabs: const [
                  Tab(text: 'Leaderboard'),
                  Tab(text: 'Search'),
                ],
              ),
            )
          : _selectedIndex == 2
              ? AppBar(
                  toolbarHeight: kToolbarHeight - 56,
                  bottom: TabBar(
                    controller: _settingsTabController,
                    tabs: const [
                      Tab(text: 'General'),
                      Tab(text: 'User Filter'),
                    ],
                  ),
                )
              : null,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      controller: _statsTabController,
                      children: [
                        Column(
                          children: [
                            _buildDropdowns(),
                            Expanded(child: _buildStatsView()),
                          ],
                        ),
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Opacity(
                                    opacity: 0.0,
                                    child: IconButton(
                                      icon: const Icon(Icons.search),
                                      onPressed: () {},
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: const InputDecoration(
                                        hintText: 'Search...',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.search),
                                    onPressed: () {
                                      setState(() {
                                        _fetchStatsData(
                                            index: 0, isSessionData: true);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            _buildSearchDropdowns(),
                            Expanded(child: _buildSearchStatsView()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildCurrentPaceView(),
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      controller: _settingsTabController,
                      children: [
                        _buildSettingsView(),
                        _buildFilterView(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run),
            label: 'Current Pace',
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

  Widget _buildDropdowns() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDropdown<String>(
              value: _tabs[_selectedTabIndex],
              items: _tabs.map((tab) {
                return DropdownMenuItem<String>(
                  value: tab,
                  child: Row(
                    children: [
                      Image.asset(
                        _tabImages[_tabs.indexOf(tab)],
                        height: 24,
                        width: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(tab),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedTabIndex = _tabs.indexOf(newValue!);
                  _fetchStatsData(index: _selectedTabIndex);
                });
              },
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDropdown<String>(
              value: _selectedType,
              items: ['Qty', 'Average', 'Fastest'].map((type) {
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
                  _fetchStatsData(index: _selectedTabIndex);
                });
              },
            ),
            _buildDropdown<String>(
              value: _selectedDays,
              items: ['1', '7', '30', '9999'].map((day) {
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
                  _fetchStatsData(index: _selectedTabIndex);
                });
              },
            ),
            _buildDropdown<String>(
              value: _selectedLimit,
              items: ['10', '30'].map((limit) {
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
                  _fetchStatsData(index: _selectedTabIndex);
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchDropdowns() {
    if (_selectedIndex != 0) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDropdown<String>(
              value: _searchAvgCV,
              items: const [
                DropdownMenuItem(
                    value: 'Avg',
                    child: Text('Average', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(
                    value: 'CVR',
                    child: Text('CVR', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(
                    value: 'CCR',
                    child: Text('CCR', style: TextStyle(fontSize: 14))),
              ],
              onChanged: (String? newValue) {
                setState(() {
                  _searchAvgCV = newValue!;
                  _fetchStatsData(index: 0, isSessionData: true);
                });
              },
            ),
            _buildDropdown<String>(
              value: _searchDays,
              items: const [
                DropdownMenuItem(
                    value: '24',
                    child: Text('24 hours', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(
                    value: '168',
                    child: Text('7 days', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(
                    value: '720',
                    child: Text('30 days', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(
                    value: '2160',
                    child: Text('3 months', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(
                    value: '4320',
                    child: Text('6 months', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(
                    value: '8640',
                    child: Text('12 months', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(
                    value: '239976',
                    child: Text('Lifetime', style: TextStyle(fontSize: 14))),
              ],
              onChanged: (String? newValue) {
                setState(() {
                  _searchDays = newValue!;
                  _fetchStatsData(index: 0, isSessionData: true);
                });
              },
            ),
            _buildDropdown<bool>(
              value: _searchStructure,
              items: const [
                DropdownMenuItem(
                    value: true,
                    child: Text('F/S Struct', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(
                    value: false,
                    child: Text('Bas/Fort', style: TextStyle(fontSize: 14))),
              ],
              onChanged: (bool? newValue) {
                setState(() {
                  _searchStructure = newValue!;
                  _fetchStatsData(index: 0, isSessionData: true);
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButton<T>(
      value: value,
      items: items,
      onChanged: onChanged,
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
                  DropdownButton<String>(
                    value: _filterType,
                    onChanged: (String? newValue) {
                      setState(() {
                        _filterType = newValue!;
                      });
                    },
                    items: <String>['No Filter', 'Live Only', 'User Filter']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
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

                                if (_filterType == 'No Filter') {
                                  return !isHidden && !isCheated;
                                } else if (_filterType == 'Live Only') {
                                  return liveAccount != null &&
                                      !isHidden &&
                                      !isCheated;
                                } else if (_filterType == 'User Filter') {
                                  final nickname = item['nickname'];
                                  return usernames.contains(nickname) &&
                                      !isHidden &&
                                      !isCheated;
                                }
                                return false;
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
                                      dense: true,
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
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            )
                                          : Text(item['nickname'] ?? 'No Name',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
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
                                                fontSize: 12,
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
                                                    fontSize: 12,
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
                                                          fontSize: 12,
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
                                                          fontSize: 12,
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

        final int mainValue = statsItem['value'].floor();
        final int qtyValue = statsItem['qty'];
        final int avgValue = statsItem['avg'].floor();

        final formattedmainTime = _formatTimeWithoutLeadingZero(mainValue);
        final formattedTime = _formatTimeWithoutLeadingZero(avgValue);

        final String selectedType = _selectedType;

        Color secondColor = Colors.black;
        Color firstColor = Colors.black;
        String firstText = '';
        String secondText = '';

        if (selectedType == 'Qty') {
          firstText = '$qtyValue';
          secondText = formattedTime;
          firstColor = (Theme.of(context).brightness == Brightness.dark)
              ? Colors.white
              : Colors.black;
          secondColor = Colors.grey;
        } else if (selectedType == 'Average') {
          firstText = formattedTime;
          secondText = '$qtyValue';
          secondColor = Colors.grey;
          firstColor = (Theme.of(context).brightness == Brightness.dark)
              ? Colors.white
              : Colors.black;
        } else if (selectedType == 'Fastest') {
          firstText = formattedmainTime;
          secondText = '$qtyValue';
          secondColor = Colors.grey;
          firstColor = (Theme.of(context).brightness == Brightness.dark)
              ? Colors.white
              : Colors.black;
        }

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
                      firstText,
                      style: TextStyle(
                        color: firstColor,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      secondText,
                      style: TextStyle(
                        color: secondColor,
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

  Widget _buildSearchStatsView() {
    if (_userstatsdata.isEmpty) {
      return const Center(
        child: Text('No stats available'),
      );
    }

    int? firstCount;
    int? previousCount;

    return ListView.builder(
      itemCount: _userstatsdata.keys.length,
      itemBuilder: (context, index) {
        final statKey = _userstatsdata.keys.elementAt(index);
        final statData = _userstatsdata[statKey];

        if ((_searchStructure &&
                (statKey == 'bastion' || statKey == 'fortress')) ||
            (!_searchStructure &&
                (statKey == 'first_structure' ||
                    statKey == 'second_structure'))) {
          return const SizedBox.shrink();
        }

        final displayName = _statKeyDisplayNames[statKey] ?? statKey;

        int imageIndex;
        switch (statKey) {
          case 'nether':
            imageIndex = 0;
            break;
          case 'bastion':
            imageIndex = 1;
            break;
          case 'fortress':
            imageIndex = 2;
            break;
          case 'first_structure':
            imageIndex = 1;
            break;
          case 'second_structure':
            imageIndex = 2;
            break;
          case 'first_portal':
            imageIndex = 3;
            break;
          case 'stronghold':
            imageIndex = 4;
            break;
          case 'end':
            imageIndex = 5;
            break;
          case 'finish':
            imageIndex = 6;
            break;
          default:
            imageIndex = -1;
        }

        final currentCount = statData['count'];
        double conversionRate;

        if (firstCount == null) {
          firstCount = currentCount;
          conversionRate = 100;
        } else {
          final denominator =
              _searchAvgCV == 'CVR' ? previousCount : firstCount;
          conversionRate = denominator != null && denominator > 0
              ? (currentCount / denominator * 100).toDouble()
              : 0;
        }

        final String displayValue;
        if (_searchAvgCV == 'Avg') {
          displayValue = statData['avg'];
        } else if (_searchAvgCV == 'CVR' || _searchAvgCV == 'CCR') {
          displayValue = (firstCount == currentCount)
              ? 'N/A'
              : '${conversionRate.toStringAsFixed(1)}%';
        } else {
          displayValue = 'N/A';
        }

        previousCount = currentCount;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          elevation: 4,
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.all(16),
            leading: imageIndex != -1
                ? Image.asset(
                    _tabImages[imageIndex],
                    height: 24,
                    width: 24,
                  )
                : null,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$currentCount',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      displayValue,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
            'There is nothing here yet :(',
          ),
          Text(
            'v$currentVersion',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Enter username...',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addUsername,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: usernames.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                      style: const TextStyle(fontSize: 14), usernames[index]),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        usernames.removeAt(index);
                      });
                      _saveUsernames();
                    },
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
