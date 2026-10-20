import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:audioplayers/audioplayers.dart';

const green = Color(0xFF087F5B);
const gold = Color(0xFFD7B65D);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await PrayerNotifications.instance.initialize();
  } catch (e) {
    debugPrint('Notification initialization error: $e');
  }
  runApp(const NourIslamApp());
}

class NourIslamApp extends StatefulWidget {
  const NourIslamApp({super.key});

  @override
  State<NourIslamApp> createState() => _NourIslamAppState();
}

class _NourIslamAppState extends State<NourIslamApp> {
  bool dark = true;

  @override
  Widget build(BuildContext context) {
    final brightness = dark ? Brightness.dark : Brightness.light;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نور الإسلام',
      theme: ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(seedColor: green, brightness: brightness),
        scaffoldBackgroundColor: dark ? const Color(0xFF08131F) : const Color(0xFFF4F7F5),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: dark ? const Color(0xFF101F2F) : Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: dark ? const Color(0xFF122335) : Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 5),
        ),
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: HomePage(
          dark: dark,
          onThemeChanged: () => setState(() => dark = !dark),
        ),
      ),
    );
  }
}

class PrayerTimesApi {
  static const names = <String, String>{
    'Fajr': 'الفجر',
    'Dhuhr': 'الظهر',
    'Asr': 'العصر',
    'Maghrib': 'المغرب',
    'Isha': 'العشاء',
  };

  final Map<String, Map<String, String>> _cache = {};

  Future<Map<String, String>> timings({
    required DateTime date,
    required double latitude,
    required double longitude,
    required int method,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final cacheKey = '$latitude|$longitude|$method|${day.year}-${day.month}-${day.day}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final apiDate = '${day.day.toString().padLeft(2, '0')}-${day.month.toString().padLeft(2, '0')}-${day.year}';
    final uri = Uri.https('api.aladhan.com', '/v1/timings/$apiDate', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'method': method.toString(),
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw Exception('تعذّر جلب مواقيت الصلاة من الإنترنت.');

    final root = jsonDecode(response.body) as Map<String, dynamic>;
    final data = root['data'] as Map<String, dynamic>;
    final raw = data['timings'] as Map<String, dynamic>;
    final result = <String, String>{};

    for (final key in names.keys) {
      final value = raw[key]?.toString() ?? '';
      final match = RegExp(r'\d{1,2}:\d{2}').firstMatch(value);
      if (match == null) throw Exception('تعذّر قراءة موعد صلاة ${names[key]}.');
      result[key] = match.group(0)!;
    }

    _cache[cacheKey] = result;
    return result;
  }

  void clearCache() => _cache.clear();
}

class PrayerMoment {
  final String name;
  final String time;
  final DateTime dateTime;
  const PrayerMoment({required this.name, required this.time, required this.dateTime});
}

class PrayerNotifications {
  PrayerNotifications._();
  static final instance = PrayerNotifications._();
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info)); // تصحيح 1
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    await plugin.initialize( // تصحيح 2
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
  }

  Future<bool> requestPermissions() async {
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    if (granted == false) return false;
    await android?.requestExactAlarmsPermission();
    final ios = plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
    return true;
  }

  Future<void> scheduleWeek({
    required PrayerTimesApi api,
    required double latitude,
    required double longitude,
    required int method,
  }) async {
    await plugin.cancelAll();
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final exactAllowed = await android?.canScheduleExactNotifications() ?? false;
    final scheduleMode = exactAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;

    final prayerEntries = PrayerTimesApi.names.entries.toList();
    for (var offset = 0; offset < 7; offset++) {
      final day = DateTime.now().add(Duration(days: offset));
      final times = await api.timings(date: day, latitude: latitude, longitude: longitude, method: method);

      for (var i = 0; i < prayerEntries.length; i++) {
        final entry = prayerEntries[i];
        final value = times[entry.key]!;
        final parts = value.split(':');
        final scheduled = DateTime(day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));

        if (!scheduled.isAfter(DateTime.now())) continue;
        final id = (day.year * 10000 + day.month * 100 + day.day) * 10 + i;

        await plugin.zonedSchedule( // تصحيح 3
          id,
          'حان وقت صلاة ${entry.value}',
          'حيّ على الصلاة • صلاة ${entry.value}',
          tz.TZDateTime.from(scheduled, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'nour_prayer_channel',
              'مواقيت الصلاة',
              channelDescription: 'تنبيهات مواقيت الصلوات الخمس',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
            iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
          ),
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: entry.key,
        );
      }
    }
  }
}

class HomePage extends StatefulWidget {
  final bool dark;
  final VoidCallback onThemeChanged;
  const HomePage({super.key, required this.dark, required this.onThemeChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PrayerTimesApi _api = PrayerTimesApi();
  int _tab = 0;
  int _method = 3;
  bool _loading = true;
  String? _error;
  Position? _position;
  DateTime _now = DateTime.now();
  Map<String, String> _today = {};
  Map<String, String> _tomorrow = {};
  Timer? _clock;
  DateTime? _loadedDate;

  static const calculationMethods = <int, String>{
    3: 'رابطة العالم الإسلامي',
    4: 'أم القرى',
    5: 'الهيئة المصرية',
    12: 'فرنسا',
    13: 'تركيا',
    21: 'المغرب',
  };

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final current = DateTime.now();
      final dateChanged = _loadedDate != null &&
          (current.year != _loadedDate!.year || current.month != _loadedDate!.month || current.day != _loadedDate!.day);
      setState(() => _now = current);
      if (dateChanged) unawaited(_refresh());
    });
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<Position> _getPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('فعّل خدمة الموقع GPS في هاتفك.');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) throw Exception('لم تسمح للتطبيق باستخدام موقعك.');
    if (permission == LocationPermission.deniedForever) throw Exception('إذن الموقع مرفوض نهائياً من إعدادات الهاتف.');
    return Geolocator.getCurrentPosition(); // تصحيح 4
  }

  Future<void> _refresh() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final position = await _getPosition();
      final now = DateTime.now();
      final today = await _api.timings(date: now, latitude: position.latitude, longitude: position.longitude, method: _method);
      final tomorrow = await _api.timings(date: now.add(const Duration(days: 1)), latitude: position.latitude, longitude: position.longitude, method: _method);

      if (!mounted) return;
      setState(() {
        _position = position;
        _today = today;
        _tomorrow = tomorrow;
        _now = DateTime.now();
        _loadedDate = DateUtils.dateOnly(_now);
        _loading = false;
      });
      unawaited(_scheduleNotifications(position).catchError((e) => debugPrint('$e')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _scheduleNotifications(Position position) async {
    await PrayerNotifications.instance.scheduleWeek(
      api: _api,
      latitude: position.latitude,
      longitude: position.longitude,
      method: _method,
    );
  }

  PrayerMoment? get _nextPrayer {
    final today = DateUtils.dateOnly(_now);
    final tomorrow = today.add(const Duration(days: 1));
    final moments = [..._moments(today, _today), ..._moments(tomorrow, _tomorrow)];
    for (final moment in moments) {
      if (moment.dateTime.isAfter(_now)) return moment;
    }
    return null;
  }

  List<PrayerMoment> _moments(DateTime date, Map<String, String> times) {
    final output = <PrayerMoment>[];
    for (final entry in PrayerTimesApi.names.entries) {
      final raw = times[entry.key];
      if (raw == null) continue;
      final parts = raw.split(':');
      output.add(PrayerMoment(
        name: entry.value,
        time: raw,
        dateTime: DateTime(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1])),
      ));
    }
    return output;
  }

  String _countdown(DateTime target) {
    final difference = target.difference(_now);
    if (difference.isNegative) return '00:00:00';
    final hours = difference.inHours.toString().padLeft(2, '0');
    final minutes = (difference.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (difference.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نور الإسلام', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'تغيير المظهر',
            onPressed: widget.onThemeChanged,
            icon: Icon(widget.dark ? Icons.light_mode : Icons.dark_mode, color: gold),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _buildPrayerTab(),
          const QuranTab(),
          const AzkarTab(),
          const TasbihTab(),
          const DailyTrackerTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.access_time), selectedIcon: Icon(Icons.access_time_filled), label: 'الصلاة'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'القرآن'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), label: 'الأذكار'),
          NavigationDestination(icon: Icon(Icons.radio_button_checked), label: 'المسبحة'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'يومي'),
        ],
      ),
    );
  }

  Widget _buildPrayerTab() {
    final next = _nextPrayer;
    if (_loading && _today.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_today.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, size: 48, color: green),
              const SizedBox(height: 12),
              Text(_error ?? 'تعذّر تحميل مواقيت الصلاة.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('حاول مرة أخرى')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF087F5B), Color(0xFF064334)]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                const Icon(Icons.mosque, color: Colors.white70, size: 36),
                const SizedBox(height: 8),
                Text(next != null ? 'الصلاة القادمة: صلاة ${next.name}' : 'مواقيت اليوم',
                    style: const TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 8),
                Text(next != null ? _countdown(next.dateTime) : '--:--:--',
                    style: const TextStyle(color: gold, fontSize: 34, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._moments(DateUtils.dateOnly(_now), _today).map((m) => Card(
            child: ListTile(
              title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(m.time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )),
        ],
      ),
    );
  }
}

class QuranTab extends StatelessWidget {
  const QuranTab({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: const [
        Card(child: ListTile(leading: Icon(Icons.menu_book, color: green), title: Text('سورة الفاتحة'), subtitle: Text('مكية • 7 آيات'))),
        Card(child: ListTile(leading: Icon(Icons.menu_book, color: green), title: Text('سورة البقرة'), subtitle: Text('مدنية • 286 آية'))),
        Card(child: ListTile(leading: Icon(Icons.menu_book, color: green), title: Text('سورة الكهف'), subtitle: Text('مكية • 110 آيات'))),
        Card(child: ListTile(leading: Icon(Icons.menu_book, color: green), title: Text('سورة يس'), subtitle: Text('مكية • 83 آية'))),
        Card(child: ListTile(leading: Icon(Icons.menu_book, color: green), title: Text('سورة الملك'), subtitle: Text('مكية • 30 آية'))),
      ],
    );
  }
}

class AzkarTab extends StatefulWidget {
  const AzkarTab({super.key});
  @override
  State<AzkarTab> createState() => _AzkarTabState();
}

class _AzkarTabState extends State<AzkarTab> {
  final List<Map<String, dynamic>> _azkar = [
    {'title': 'أذكار الصباح والمساء', 'text': 'سبحان الله وبحمده، عدد خلقه، ورضا نفسه، وزنة عرشه.', 'count': 3},
    {'title': 'الاستغفار', 'text': 'أستغفر الله العظيم وأتوب إليه.', 'count': 10},
    {'title': 'الصلاة على النبي ﷺ', 'text': 'اللهم صلِّ وسلم على نبينا محمد.', 'count': 10},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _azkar.length,
      itemBuilder: (ctx, i) {
        final item = _azkar[i];
        final count = item['count'] as int;
        return Card(
          child: ListTile(
            title: Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: gold)),
            subtitle: Text(item['text'] as String),
            trailing: CircleAvatar(
              backgroundColor: green,
              child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            onTap: () {
              if (count > 0) setState(() => item['count'] = count - 1);
            },
          ),
        );
      },
    );
  }
}

class TasbihTab extends StatefulWidget {
  const TasbihTab({super.key});
  @override
  State<TasbihTab> createState() => _TasbihTabState();
}

class _TasbihTabState extends State<TasbihTab> {
  int _counter = 0;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: gold)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => setState(() => _counter++),
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: green),
              child: Center(
                child: Text('$_counter', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () => setState(() => _counter = 0), child: const Text('تصفير')),
        ],
      ),
    );
  }
}

class DailyTrackerTab extends StatefulWidget {
  const DailyTrackerTab({super.key});
  @override
  State<DailyTrackerTab> createState() => _DailyTrackerTabState();
}

class _DailyTrackerTabState extends State<DailyTrackerTab> {
  final Map<String, bool> _goals = {
    'الصلوات الخمس في وقتها': true,
    'أذكار الصباح والمساء': true,
    'قراءة ورد القرآن': true,
    'صلاة الوتر': false,
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: _goals.entries.map((e) => Card(
        child: CheckboxListTile(
          title: Text(e.key),
          value: e.value,
          activeColor: green,
          onChanged: (v) => setState(() => _goals[e.key] = v ?? false),
        ),
      )).toList(),
    );
  }
}
