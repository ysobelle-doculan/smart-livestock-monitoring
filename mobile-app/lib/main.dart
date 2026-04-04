import 'package:flutter/material.dart';
import 'services/cosmos_service.dart';

void main() {
  runApp(const SheepHealthApp());
}

class SheepHealthApp extends StatelessWidget {
  const SheepHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Livestock Monitoring',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF4F7F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
        ),
      ),
      home: const MainNavigationPage(),
    );
  }
}

//////////////////////////////////////////////////////////////
// SPLASH / LOADING PAGE
//////////////////////////////////////////////////////////////

class SplashLoadingPage extends StatefulWidget {
  const SplashLoadingPage({super.key});

  @override
  State<SplashLoadingPage> createState() => _SplashLoadingPageState();
}

class _SplashLoadingPageState extends State<SplashLoadingPage> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // You can prefetch some common data here if you want.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Loading farm data...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// MAIN NAVIGATION
//////////////////////////////////////////////////////////////

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _index = 0;

  final List<Widget> pages = const [
    DashboardPage(),
    AnimalsPage(),
    AlertsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets),
            label: "Animals",
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning),
            label: "Alerts",
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// DASHBOARD PAGE - UPDATED DATA SOURCES
//////////////////////////////////////////////////////////////

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool loading = true;
  List<Map<String, dynamic>> telemetry = [];
  int totalAnimals = 0;
  int sickAnimals = 0; // from HealthStatus
  int highTempCount = 0; // from Telemetry
  int highHRCount = 0;   // from Telemetry
  String farmStatus = "Healthy";

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => loading = true);

    try {
      final animals = await CosmosService.getAnimals();
      final sickData = await CosmosService.getAllSickAnimals(); // HealthStatus

      totalAnimals = animals.length;
      sickAnimals = sickData.length;

      int tempCount = 0;
      int hrCount = 0;
      List<Map<String, dynamic>> allTelemetry = [];

      for (var a in animals) {
        final id = a['animalID'] ?? a['id'];
        final data = await CosmosService.getLatestTelemetry(id); // Telemetry

        if (data.isNotEmpty) {
          final latest = data.first;
          final temp = (latest['body_temp_c'] ?? 0).toDouble();
          final hr = (latest['heart_rate_bpm'] ?? 0).toDouble();

          if (temp > 40) tempCount++;
          if (hr > 120) hrCount++;

          allTelemetry.add(latest);
        }
      }

      setState(() {
        telemetry = allTelemetry;
        highTempCount = tempCount;
        highHRCount = hrCount;
        farmStatus = (sickAnimals > 0 || tempCount > 0 || hrCount > 0)
            ? "Warning"
            : "Healthy";
        loading = false;
      });
    } catch (e) {
      debugPrint('Dashboard load failed: $e');
      setState(() => loading = false);
    }
  }

  double _avgTemp() {
    if (telemetry.isEmpty) return 0;
    final temps = telemetry
        .map((e) => (e['body_temp_c'] as num?)?.toDouble() ?? 0)
        .where((t) => t > 0)
        .toList();
    if (temps.isEmpty) return 0;
    return temps.reduce((a, b) => a + b) / temps.length;
  }

  int _avgHR() {
    if (telemetry.isEmpty) return 0;
    final hrs = telemetry
        .map((e) => (e['heart_rate_bpm'] as num?)?.toInt() ?? 0)
        .where((h) => h > 0)
        .toList();
    if (hrs.isEmpty) return 0;
    return (hrs.reduce((a, b) => a + b) / hrs.length).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Livestock Overview",
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 30),

                    // Metrics Row
                    Row(
                      children: [
                        Expanded(
                          child: _metricCard(
                              "Avg Temperature",
                              "${_avgTemp().toStringAsFixed(1)}°C",
                              Icons.thermostat,
                              Colors.orange),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _metricCard(
                              "Avg Heart Rate",
                              "${_avgHR()} bpm",
                              Icons.favorite,
                              Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Farm Conditions
                    const Text(
                      "Farm Conditions",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _conditionCard("Total Animals", totalAnimals.toString(),
                        Icons.pets, Colors.green),
                    const SizedBox(height: 12),
                    _conditionCard("Sick Animals (ML)", sickAnimals.toString(),
                        Icons.medical_services, Colors.purple),
                    const SizedBox(height: 12),
                    _conditionCard("High Temperature", highTempCount.toString(),
                        Icons.thermostat, Colors.red),
                    const SizedBox(height: 12),
                    _conditionCard("High Heart Rate", highHRCount.toString(),
                        Icons.favorite, Colors.orange),
                    const SizedBox(height: 12),
                    _conditionCard(
                        "Farm Status",
                        farmStatus,
                        farmStatus == "Healthy"
                            ? Icons.check_circle
                            : Icons.warning,
                        farmStatus == "Healthy" ? Colors.green : Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      "Last Updated: ${DateTime.now().toLocal()}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _metricCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 34),
          const SizedBox(height: 16),
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 6),
          Text(value,
              style:
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _conditionCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            "$label: $value",
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// ANIMALS PAGE
//////////////////////////////////////////////////////////////

class AnimalsPage extends StatefulWidget {
  const AnimalsPage({super.key});

  @override
  State<AnimalsPage> createState() => _AnimalsPageState();
}

class _AnimalsPageState extends State<AnimalsPage> {
  bool loading = true;
  bool showOnlyAlerts = false;
  String searchQuery = "";
  String speciesFilter = "All";

  List<Map<String, dynamic>> animals = [];
  final List<String> speciesOptions = ["All", "Cow", "Sheep", "Goat", "Camel"];

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  Future<void> _loadAnimals() async {
    setState(() => loading = true);

    try {
      final allAnimals = await CosmosService.getAnimals();

      // Fetch latest telemetry and compute status
      final futures = allAnimals.map((a) async {
        final id = a['animalID'] ?? a['id'];
        final telemetry = await CosmosService.getLatestTelemetry(id);
        final latest = telemetry.isNotEmpty ? telemetry.first : {};

        final temp = (latest['body_temp_c'] ?? 0).toDouble();
        final hr = (latest['heart_rate_bpm'] ?? 0).toDouble();
        final health = await CosmosService.getLatestHealthStatus(id);

        final isSick = health?['isSick'] ?? false;
        final cause = health?['cause'] ?? 'unknown';

        final status = isSick ? "Sick" : "Healthy";

        

        // Map species from DB (correct field is 'species')
        String type = (latest['species'] ?? 'Unknown').toString().trim();

        // Capitalize first letter for display
        if (type.isNotEmpty) {
          type = type[0].toUpperCase() + type.substring(1).toLowerCase();
        }

        return {
          'id': id,
          'animalID': id,
          'animalType': type, // <-- used for filtering
          'body_temp_c': temp,
          'heart_rate_bpm': hr,
          'status': status,
          'breed': latest['breed'] ?? 'Unknown',
          'age': latest['age'] ?? 0,
          'isSick': isSick,
          'cause': cause,
        };
      }).toList();

      final fullAnimals = await Future.wait(futures);

      setState(() {
        animals = fullAnimals;
        loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load animals: $e');
      setState(() => loading = false);
    }
  }

  bool _isUnhealthy(Map<String, dynamic> animal) {
    return animal['isSick'] == true;
  }

  List<Map<String, dynamic>> _filteredAnimals() {
    var filtered = animals;

    // Search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((a) {
        final id = (a['animalID'] ?? a['id']).toString();
        return id.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    // Species filter (normalized)
    if (speciesFilter != "All") {
      filtered = filtered.where((a) {
        final type = (a['animalType'] ?? '').toString().trim().toLowerCase();
        return type == speciesFilter.toLowerCase();
      }).toList();
    }

    // Alerts filter
    if (showOnlyAlerts) {
      filtered = filtered.where(_isUnhealthy).toList();
    }

    return filtered;
  }

  Map<String, List<Map<String, dynamic>>> _groupedAnimals() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var animal in _filteredAnimals()) {
      final type = (animal['animalType'] ?? 'Unknown').toString();
      grouped.putIfAbsent(type, () => []).add(animal);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedAnimals();

    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnimals,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                children: [
                  const Text(
                    "Animals",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Search bar
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Search by Animal ID",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => searchQuery = value);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Species filter dropdown
                  DropdownButton<String>(
                    value: speciesFilter,
                    items: speciesOptions
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => speciesFilter = value ?? "All");
                    },
                  ),

                  const SizedBox(height: 16),

                  // Alerts toggle
                  SwitchListTile(
                    value: showOnlyAlerts,
                    title: const Text("Show Only Sick Animals"),
                    onChanged: (value) {
                      setState(() => showOnlyAlerts = value);
                    },
                  ),

                  const SizedBox(height: 20),

                  // Grouped display
                  for (final entry in grouped.entries) ...[
                    Text(
                      entry.key,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    ...entry.value.map((animal) {
                      final id = animal['animalID'] ?? animal['id'];
                      final isUnhealthy = _isUnhealthy(animal);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: isUnhealthy
                              ? Border.all(color: Colors.red, width: 2)
                              : null,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                isUnhealthy ? Colors.red : const Color(0xFF2E7D32),
                            child: const Icon(Icons.pets, color: Colors.white),
                          ),
                          title: Text("Animal ID: $id"),
                          subtitle: Text(
                            isUnhealthy
                                ? "⚠ ${animal['cause']}"
                                : "Healthy",
                          ),
                          ),
                      );
                    }),

                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
    );
  }
}

//////////////////////////////////////////////////////////////
// ALERTS PAGE
//////////////////////////////////////////////////////////////

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  bool loading = true;
  List<Map<String, dynamic>> alerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => loading = true);

    try {
      final results = await CosmosService.getAllSickAnimals();
      if (!mounted) return; // ✅ IMPORTANT
      List<Map<String, dynamic>> list = [];

      for (var h in results) {
        list.add({
          'id': h['animalID'],
          'cause': h['cause'],
          'score': (h['anomaly_score'] ?? 0).toDouble(),
          'time': h['timestamp'],
        });
      }

      debugPrint("SICK DATA: $list"); // 🔍 DEBUG

      setState(() {
        alerts = list;
        loading = false;
      });
    } catch (e) {
      debugPrint("ALERT ERROR: $e");
      if (!mounted) return; // ✅ IMPORTANT
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Alerts")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : alerts.isEmpty
              ? const Center(
                  child: Text(
                    "No Alerts",
                    style: TextStyle(fontSize: 20, color: Colors.green),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red, width: 1),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.warning, color: Colors.red),
                        title: Text("Animal ID: ${alert['id']}"),
                        subtitle: Text(
                            "Cause: ${alert['cause']}\nRisk Score: ${alert['score'].toStringAsFixed(2)}"),
                        trailing: const Icon(Icons.arrow_forward_ios),
                      ),
                    );
                  },
                ),
    );
  }
}


//////////////////////////////////////////////////////////////
// SETTINGS PAGE (MODERN UI MATCHING APP DESIGN)
//////////////////////////////////////////////////////////////

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static final List<_SettingsCategory> categories = [
    _SettingsCategory('User Account & Permissions', Icons.person, const UserAccountSettingsPage()),
    _SettingsCategory('Device & Sensor Management', Icons.memory, const DeviceSensorSettingsPage()),
    _SettingsCategory('Alert & Notification Settings', Icons.notifications_active, const AlertSettingsPage()),
    _SettingsCategory('Environmental Monitor Settings', Icons.thermostat, const EnvironmentalSettingsPage()),
    _SettingsCategory('Data Management & Privacy', Icons.privacy_tip, const DataPrivacySettingsPage()),
    _SettingsCategory('System Preferences', Icons.settings, const SystemPreferencesPage()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Settings & Configuration",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            // SETTINGS CATEGORIES
            ...categories.map((category) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _modernTile(
                    icon: category.icon,
                    title: category.title,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => category.subPage),
                    ),
                  ),
                )),

            const SizedBox(height: 40),

            // HELP & SUPPORT
            const Text(
              "Help & Support",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "User Guides & Tutorials",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            _modernHelpTile(
              icon: Icons.play_circle_outline,
              title: "Getting Started with Sensors",
              subtitle: "How to install devices and onboard your herd.",
            ),
            _modernHelpTile(
              icon: Icons.play_circle_outline,
              title: "Understanding Dashboards",
              subtitle: "Learn how to interpret vitals, alerts and trends.",
            ),

            const SizedBox(height: 30),

            const Text(
              "Contact Support",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            _modernHelpTile(
              icon: Icons.email_outlined,
              title: "Email Helpdesk",
              subtitle: "support@yourfarmplatform.com",
              showArrow: true,
            ),
            _modernHelpTile(
              icon: Icons.phone_outlined,
              title: "Call Support",
              subtitle: "+XXX XXX XXXX",
            ),

            const SizedBox(height: 30),

            const Text(
              "FAQs & Troubleshooting",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            _modernHelpTile(
              icon: Icons.help_outline,
              title: "No data from a sensor",
              subtitle: "Check battery, connectivity and animal assignment.",
            ),
            _modernHelpTile(
              icon: Icons.help_outline,
              title: "Unexpected alert spikes",
              subtitle: "Review farm conditions and sensor calibration.",
            ),
            _modernHelpTile(
              icon: Icons.help_outline,
              title: "App not syncing",
              subtitle: "Verify network connection and retry manual sync.",
            ),
          ],
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
// MODERN TILE (For Settings Categories)
//////////////////////////////////////////////////////////////

Widget _modernTile({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
            child: Icon(icon, color: const Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
    ),
  );
}

//////////////////////////////////////////////////////////////
// MODERN HELP TILE
//////////////////////////////////////////////////////////////

Widget _modernHelpTile({
  required IconData icon,
  required String title,
  required String subtitle,
  bool showArrow = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
            child: Icon(icon, color: const Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (showArrow)
            const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
    ),
  );
}

//////////////////////////////////////////////////////////////
// SETTINGS CATEGORY CLASS
//////////////////////////////////////////////////////////////

class _SettingsCategory {
  final String title;
  final IconData icon;
  final Widget subPage;
  const _SettingsCategory(this.title, this.icon, this.subPage);
}

//////////////////////////////////////////////////////////////
// SUB SETTINGS SCAFFOLD
//////////////////////////////////////////////////////////////

Widget _SubSettingsScaffold(String title, List<Widget> tiles) {
  return Scaffold(
    appBar: AppBar(
      title: Text(title),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      children: tiles,
    ),
  );
}

Widget _settingTile(IconData icon, String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: _modernTile(
      icon: icon,
      title: title,
      onTap: () {},
    ),
  );
}

//////////////////////////////////////////////////////////////
// USER ACCOUNT
//////////////////////////////////////////////////////////////

class UserAccountSettingsPage extends StatelessWidget {
  const UserAccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => _SubSettingsScaffold(
        'User Account & Permissions',
        [
          _settingTile(Icons.person, 'Manage Profile'),
          _settingTile(Icons.admin_panel_settings, 'Role-based Access Control'),
          _settingTile(Icons.lock, 'Password & Authentication Settings'),
          _settingTile(Icons.group_add, 'Manage User Invitations/Removals'),
        ],
      );
}

//////////////////////////////////////////////////////////////
// DEVICE & SENSOR
//////////////////////////////////////////////////////////////

class DeviceSensorSettingsPage extends StatelessWidget {
  const DeviceSensorSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => _SubSettingsScaffold(
        'Device & Sensor Management',
        [
          _settingTile(Icons.memory, 'Sensor Status Overview'),
          _settingTile(Icons.add_box, 'Add/Remove/Resync Sensor Modules'),
          _settingTile(Icons.timer, 'Configure Sampling & Power Modes'),
          _settingTile(Icons.tune, 'Sensor Calibration Settings'),
          _settingTile(Icons.system_update, 'Sensor Firmware Updates'),
        ],
      );
}

//////////////////////////////////////////////////////////////
// ALERT SETTINGS
//////////////////////////////////////////////////////////////

class AlertSettingsPage extends StatelessWidget {
  const AlertSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => _SubSettingsScaffold(
        'Alert & Notification Settings',
        [
          _settingTile(Icons.notifications_active, 'Customize Alert Thresholds'),
          _settingTile(Icons.sms, 'Notification Methods (Push/SMS/Email)'),
          _settingTile(Icons.priority_high, 'Alert Priority & Escalation'),
          _settingTile(Icons.timer_off, 'Quiet Hours & Suppression'),
        ],
      );
}

//////////////////////////////////////////////////////////////
// ENVIRONMENT
//////////////////////////////////////////////////////////////

class EnvironmentalSettingsPage extends StatelessWidget {
  const EnvironmentalSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => _SubSettingsScaffold(
        'Environmental Monitor Settings',
        [
          _settingTile(Icons.thermostat, 'Set Environmental Alert Thresholds'),
          _settingTile(Icons.cloud, 'Choose Data Sources'),
          _settingTile(Icons.update, 'Refresh Interval Settings'),
        ],
      );
}

//////////////////////////////////////////////////////////////
// DATA & PRIVACY
//////////////////////////////////////////////////////////////

class DataPrivacySettingsPage extends StatelessWidget {
  const DataPrivacySettingsPage({super.key});

  @override
  Widget build(BuildContext context) => _SubSettingsScaffold(
        'Data Management & Privacy',
        [
          _settingTile(Icons.file_download, 'Export Data (CSV/PDF)'),
          _settingTile(Icons.history_toggle_off, 'Data Retention Policies'),
          _settingTile(Icons.privacy_tip, 'Consent & Third-party Access'),
        ],
      );
}

//////////////////////////////////////////////////////////////
// SYSTEM PREFERENCES
//////////////////////////////////////////////////////////////

class SystemPreferencesPage extends StatelessWidget {
  const SystemPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) => _SubSettingsScaffold(
        'System Preferences',
        [
          _settingTile(Icons.language, 'Language Selection'),
          _settingTile(Icons.straighten, 'Units of Measurement'),
          _settingTile(Icons.color_lens, 'Themes & Interface'),
        ],
      );
}
