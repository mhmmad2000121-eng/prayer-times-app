
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

// ============================================================
// APP THEME
// ============================================================

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          brightness: brightness,
        ),
        scaffoldBackgroundColor:
            dark ? const Color(0xFF08131F) : const Color(0xFFF4F7F5),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor:
              dark ? const Color(0xFF101F2F) : Colors.white,
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

// ============================================================
// PRAYER TIMES API
// ============================================================

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

    final cacheKey =
        '$latitude|$longitude|$method|${day.year}-${day.month}-${day.day}';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final apiDate =
        '${day.day.toString().padLeft(2, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.year}';

    final uri = Uri.https(
      'api.aladhan.com',
      '/v1/timings/$apiDate',
      {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'method': method.toString(),
      },
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('تعذّر جلب مواقيت الصلاة من الإنترنت.');
    }

    final root = jsonDecode(response.body) as Map<String, dynamic>;
    final data = root['data'] as Map<String, dynamic>;
    final raw = data['timings'] as Map<String, dynamic>;

    final result = <String, String>{};

    for (final key in names.keys) {
      final value = raw[key]?.toString() ?? '';
      final match = RegExp(r'\d{1,2}:\d{2}').firstMatch(value);

      if (match == null) {
        throw Exception('تعذّر قراءة موعد صلاة ${names[key]}.');
      }

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

  const PrayerMoment({
    required this.name,
    required this.time,
    required this.dateTime,
  });
}

// ============================================================
// LOCAL PRAYER NOTIFICATIONS
// ============================================================

class PrayerNotifications {
  PrayerNotifications._();

  static final instance = PrayerNotifications._();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
  }

  Future<bool> requestPermissions() async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final granted = await android?.requestNotificationsPermission();

    if (granted == false) {
      return false;
    }

    // Requests Android's exact-alarm access where supported.
    // If unavailable, the app falls back to inexact scheduling.
    await android?.requestExactAlarmsPermission();

    final ios = plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return true;
  }

  Future<void> scheduleWeek({
    required PrayerTimesApi api,
    required double latitude,
    required double longitude,
    required int method,
  }) async {
    await plugin.cancelAll();

    final android = plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final exactAllowed =
        await android?.canScheduleExactNotifications() ?? false;

    final scheduleMode = exactAllowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final prayerEntries = PrayerTimesApi.names.entries.toList();

    for (var offset = 0; offset < 7; offset++) {
      final day = DateTime.now().add(Duration(days: offset));

      final times = await api.timings(
        date: day,
        latitude: latitude,
        longitude: longitude,
        method: method,
      );

      for (var i = 0; i < prayerEntries.length; i++) {
        final entry = prayerEntries[i];
        final value = times[entry.key]!;

        final parts = value.split(':');

        final scheduled = DateTime(
          day.year,
          day.month,
          day.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );

        if (!scheduled.isAfter(DateTime.now())) {
          continue;
        }

        final id =
            (day.year * 10000 + day.month * 100 + day.day) * 10 + i;

        await plugin.zonedSchedule(
          id: id,
          title: 'حان وقت صلاة ${entry.value}',
          body: 'حيّ على الصلاة • صلاة ${entry.value}',
          scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'nour_prayer_channel',
              'مواقيت الصلاة',
              channelDescription: 'تنبيهات مواقيت الصلوات الخمس',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: scheduleMode,
          payload: entry.key,
        );
      }
    }
  }
}

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatefulWidget {
  final bool dark;
  final VoidCallback onThemeChanged;

  const HomePage({
    super.key,
    required this.dark,
    required this.onThemeChanged,
  });

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
          (current.year != _loadedDate!.year ||
              current.month != _loadedDate!.month ||
              current.day != _loadedDate!.day);

      setState(() => _now = current);

      if (dateChanged) {
        unawaited(_refresh());
      }
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

    if (!enabled) {
      throw Exception('فعّل خدمة الموقع GPS في هاتفك.');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('لم تسمح للتطبيق باستخدام موقعك.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'إذن الموقع مرفوض نهائياً. فعّله من إعدادات التطبيق.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final position = await _getPosition();
      final now = DateTime.now();

      final today = await _api.timings(
        date: now,
        latitude: position.latitude,
        longitude: position.longitude,
        method: _method,
      );

      final tomorrow = await _api.timings(
        date: now.add(const Duration(days: 1)),
        latitude: position.latitude,
        longitude: position.longitude,
        method: _method,
      );

      if (!mounted) return;

      setState(() {
        _position = position;
        _today = today;
        _tomorrow = tomorrow;
        _now = DateTime.now();
        _loadedDate = DateUtils.dateOnly(_now);
        _loading = false;
      });

      unawaited(
        _scheduleNotifications(position).catchError((Object error) {
          debugPrint('Prayer notifications error: $error');
        }),
      );
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

  Future<void> _enableNotifications() async {
    try {
      final allowed =
          await PrayerNotifications.instance.requestPermissions();

      if (!mounted) return;

      if (!allowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('اسمح للتطبيق بإرسال الإشعارات من إعدادات الهاتف.'),
          ),
        );
        return;
      }

      await _refresh();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم السماح بالإشعارات وجدولة مواعيد الصلاة.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر تفعيل التنبيهات: $e')),
      );
    }
  }

  List<PrayerMoment> _moments(
    DateTime date,
    Map<String, String> times,
  ) {
    final output = <PrayerMoment>[];

    for (final entry in PrayerTimesApi.names.entries) {
      final raw = times[entry.key];

      if (raw == null) continue;

      final parts = raw.split(':');

      output.add(
        PrayerMoment(
          name: entry.value,
          time: raw,
          dateTime: DateTime(
            date.year,
            date.month,
            date.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          ),
        ),
      );
    }

    return output;
  }

  PrayerMoment? get _nextPrayer {
    final today = DateUtils.dateOnly(_now);
    final tomorrow = today.add(const Duration(days: 1));

    final moments = [
      ..._moments(today, _today),
      ..._moments(tomorrow, _tomorrow),
    ];

    for (final moment in moments) {
      if (moment.dateTime.isAfter(_now)) {
        return moment;
      }
    }

    return null;
  }

  String _countdown(DateTime target) {
    final difference = target.difference(_now);

    if (difference.isNegative) return '00:00:00';

    final hours = difference.inHours.toString().padLeft(2, '0');
    final minutes =
        (difference.inMinutes % 60).toString().padLeft(2, '0');
    final seconds =
        (difference.inSeconds % 60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'نور الإسلام',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'تفعيل الإشعارات',
            onPressed: _enableNotifications,
            icon: const Icon(Icons.notifications_active_outlined),
          ),
          IconButton(
            tooltip: 'تغيير المظهر',
            onPressed: widget.onThemeChanged,
            icon: Icon(
              widget.dark ? Icons.light_mode : Icons.dark_mode,
              color: gold,
            ),
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
          NavigationDestination(
            icon: Icon(Icons.access_time),
            selectedIcon: Icon(Icons.access_time_filled),
            label: 'الصلاة',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book),
            label: 'القرآن',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            label: 'الأذكار',
          ),
          NavigationDestination(
            icon: Icon(Icons.radio_button_checked),
            label: 'المسبحة',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            label: 'يومي',
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTab() {
    final next = _nextPrayer;

    if (_loading && _today.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_today.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, size: 48, color: green),
              const SizedBox(height: 12),
              Text(
                _error ?? 'تعذّر تحميل مواقيت الصلاة.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('حاول مرة أخرى'),
              ),
            ],
          ),
        ),
      );
    }

    final latitude = _position?.latitude.toStringAsFixed(3) ?? '--';
    final longitude = _position?.longitude.toStringAsFixed(3) ?? '--';

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on, color: green),
                      SizedBox(width: 6),
                      Text(
                        'موقع الهاتف الحالي',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('خط العرض: $latitude  •  خط الطول: $longitude'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Text('طريقة حساب المواقيت')),
                      DropdownButton<int>(
                        value: _method,
                        items: calculationMethods.entries
                            .map(
                              (e) => DropdownMenuItem<int>(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _method = value);
                          _api.clearCache();
                          unawaited(_refresh());
                        },
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث الموقع والمواقيت'),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF087F5B), Color(0xFF064334)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.mosque,
                  color: Colors.white,
                  size: 36,
                ),
                const SizedBox(height: 10),
                Text(
                  next == null
                      ? 'الصلاة القادمة'
                      : 'الصلاة القادمة: ${next.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  next == null ? '--:--:--' : _countdown(next.dateTime),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: gold,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (next != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'موعد الصلاة ${next.time}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'مواقيت اليوم',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          ..._moments(DateUtils.dateOnly(_now), _today).map((prayer) {
            final active = next?.name == prayer.name &&
                DateUtils.isSameDay(prayer.dateTime, next?.dateTime);

            return Card(
              child: ListTile(
                leading: Icon(
                  Icons.notifications_active_outlined,
                  color: active ? gold : green,
                ),
                title: Text(
                  prayer.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  prayer.time,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          const Text(
            'المواقيت محسوبة آلياً؛ قد تختلف عن توقيت المسجد المحلي.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// QURAN API
// ============================================================

class SurahInfo {
  final int number;
  final String name;
  final String englishName;
  final int ayahCount;

  const SurahInfo({
    required this.number,
    required this.name,
    required this.englishName,
    required this.ayahCount,
  });
}

class AyahInfo {
  final int globalNumber;
  final int numberInSurah;
  final String text;

  const AyahInfo({
    required this.globalNumber,
    required this.numberInSurah,
    required this.text,
  });
}

class TafsirEdition {
  final String identifier;
  final String name;

  const TafsirEdition({
    required this.identifier,
    required this.name,
  });
}

class QuranApi {
  static const host = 'api.alquran.cloud';

  static Future<Map<String, dynamic>> _get(String path) async {
    final response = await http
        .get(Uri.https(host, '/v1$path'))
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('تعذّر الاتصال بخدمة القرآن الكريم.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (json['code'] != 200) {
      throw Exception('خدمة القرآن أعادت خطأ.');
    }

    return json['data'] as Map<String, dynamic>;
  }

  static Future<List<SurahInfo>> getSurahs() async {
    final data = await _get('/surah');
    final items = data as List<dynamic>;

    return items.map((item) {
      final s = item as Map<String, dynamic>;

      return SurahInfo(
        number: s['number'] as int,
        name: s['name'].toString(),
        englishName: s['englishName'].toString(),
        ayahCount: s['numberOfAyahs'] as int,
      );
    }).toList();
  }

  static Future<List<AyahInfo>> getAyahs(int surahNumber) async {
    final data = await _get('/surah/$surahNumber/quran-uthmani');
    final items = data['ayahs'] as List<dynamic>;

    return items.map((item) {
      final a = item as Map<String, dynamic>;

      return AyahInfo(
        globalNumber: a['number'] as int,
        numberInSurah: a['numberInSurah'] as int,
        text: a['text'].toString(),
      );
    }).toList();
  }

  static Future<List<TafsirEdition>> getTafsirEditions() async {
    final response = await http
        .get(
          Uri.https(
            host,
            '/v1/edition',
            {
              'format': 'text',
              'language': 'ar',
              'type': 'tafsir',
            },
          ),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('تعذّر تحميل قائمة التفاسير.');
    }

    final root = jsonDecode(response.body) as Map<String, dynamic>;
    final items = root['data'] as List<dynamic>;

    final editions = items.map((item) {
      final e = item as Map<String, dynamic>;

      return TafsirEdition(
        identifier: e['identifier'].toString(),
        name: e['name'].toString(),
      );
    }).toList();

    editions.sort((a, b) {
      if (a.identifier == 'ar.muyassar') return -1;
      if (b.identifier == 'ar.muyassar') return 1;
      return a.name.compareTo(b.name);
    });

    return editions;
  }

  static Future<String> getTafsir({
    required int surah,
    required int ayah,
    required String edition,
  }) async {
    final data = await _get('/ayah/$surah:$ayah/$edition');
    return data['text']?.toString() ?? 'لا يوجد تفسير متاح لهذه الآية.';
  }
}

// ============================================================
// QURAN SURAH LIST
// ============================================================

class QuranTab extends StatefulWidget {
  const QuranTab({super.key});

  @override
  State<QuranTab> createState() => _QuranTabState();
}

class _QuranTabState extends State<QuranTab> {
  List<SurahInfo> _surahs = [];
  String _search = '';
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await QuranApi.getSurahs();

      if (!mounted) return;

      setState(() {
        _surahs = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _surahs.where((s) {
      return s.name.contains(_search) ||
          s.englishName.toLowerCase().contains(_search.toLowerCase()) ||
          s.number.toString() == _search;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (value) => setState(() => _search = value.trim()),
            decoration: InputDecoration(
              hintText: 'ابحث عن سورة...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final surah = results[index];

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: green,
                              foregroundColor: Colors.white,
                              child: Text('${surah.number}'),
                            ),
                            title: Text(
                              'سورة ${surah.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${surah.ayahCount} آية • ${surah.englishName}',
                            ),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SurahPage(surah: surah),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ============================================================
// SURAH READER + AUDIO + TAFSIR
// ============================================================

class SurahPage extends StatefulWidget {
  final SurahInfo surah;

  const SurahPage({
    super.key,
    required this.surah,
  });

  @override
  State<SurahPage> createState() => _SurahPageState();
}

class _SurahPageState extends State<SurahPage> {
  final AudioPlayer _player = AudioPlayer();

  List<AyahInfo> _ayahs = [];
  List<TafsirEdition> _editions = [];

  String? _selectedTafsir;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ayahs = await QuranApi.getAyahs(widget.surah.number);

      List<TafsirEdition> editions = [];

      try {
        editions = await QuranApi.getTafsirEditions();
      } catch (e) {
        debugPrint('Tafsir editions unavailable: $e');
      }

      if (!mounted) return;

      setState(() {
        _ayahs = ayahs;
        _editions = editions;

        if (editions.isNotEmpty) {
          _selectedTafsir = editions.first.identifier;
        }

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _playAyah(AyahInfo ayah) async {
    try {
      final url =
          'https://cdn.islamic.network/quran/audio/128/ar.alafasy/'
          '${ayah.globalNumber}.mp3';

      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر تشغيل التلاوة: $e')),
      );
    }
  }

  void _showTafsir(AyahInfo ayah) {
    final edition = _selectedTafsir;

    if (edition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد خدمة تفسير متاحة حالياً.'),
        ),
      );
      return;
    }

    final future = QuranApi.getTafsir(
      surah: widget.surah.number,
      ayah: ayah.numberInSurah,
      edition: edition,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.75,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفسير سورة ${widget.surah.name} • الآية '
                    '${ayah.numberInSurah}',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    ayah.text,
                    style: const TextStyle(fontSize: 19, height: 1.9),
                  ),
                  const Divider(height: 28),
                  Expanded(
                    child: FutureBuilder<String>(
                      future: future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return const SingleChildScrollView(
                            child: Text(
                              'تعذّر جلب التفسير. تحقق من اتصال الإنترنت '
                              'ثم حاول مرة أخرى.',
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          child: Text(
                            snapshot.data ?? 'لا يوجد تفسير متاح.',
                            style: const TextStyle(
                              fontSize: 17,
                              height: 1.9,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('سورة ${widget.surah.name}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_editions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Text('التفسير:'),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedTafsir,
                                items: _editions
                                    .map(
                                      (edition) => DropdownMenuItem<String>(
                                        value: edition.identifier,
                                        child: Text(
                                          edition.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => _selectedTafsir = value);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _ayahs.length,
                        itemBuilder: (context, index) {
                          final ayah = _ayahs[index];

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    ayah.text,
                                    textAlign: TextAlign.justify,
                                    style: const TextStyle(
                                      fontSize: 23,
                                      height: 2.0,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: green,
                                        foregroundColor: Colors.white,
                                        child: Text(
                                          '${ayah.numberInSurah}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: 'استمع للآية',
                                        onPressed: () => _playAyah(ayah),
                                        icon: const Icon(
                                          Icons.play_circle_outline,
                                          color: green,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'التفسير',
                                        onPressed: () => _showTafsir(ayah),
                                        icon: const Icon(
                                          Icons.menu_book_outlined,
                                          color: gold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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

// ============================================================
// ADHKAR COUNTERS
// ============================================================

class ZikrItem {
  final String title;
  final String text;
  final int target;

  int count = 0;

  ZikrItem({
    required this.title,
    required this.text,
    required this.target,
  });
}

class AzkarTab extends StatefulWidget {
  const AzkarTab({super.key});

  @override
  State<AzkarTab> createState() => _AzkarTabState();
}

class _AzkarTabState extends State<AzkarTab> {
  final List<ZikrItem> _items = [
    ZikrItem(
      title: 'التسبيح',
      text: 'سبحان الله وبحمده',
      target: 100,
    ),
    ZikrItem(
      title: 'الاستغفار',
      text: 'أستغفر الله العظيم وأتوب إليه',
      target: 100,
    ),
    ZikrItem(
      title: 'الصلاة على النبي ﷺ',
      text: 'اللهم صل وسلم على نبينا محمد',
      target: 100,
    ),
    ZikrItem(
      title: 'الحوقلة',
      text: 'لا حول ولا قوة إلا بالله',
      target: 100,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          'الأذكار',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ..._items.map((item) {
          final completed = item.count >= item.target;

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  if (item.count < item.target) {
                    item.count++;
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.text,
                      style: const TextStyle(fontSize: 20, height: 1.8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      completed
                          ? 'اكتمل العدد ✓'
                          : 'العدد: ${item.count} من ${item.target}',
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: item.count / item.target,
                      color: green,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => item.count = 0),
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة العد'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ============================================================
// TASBIH
// ============================================================

class TasbihTab extends StatefulWidget {
  const TasbihTab({super.key});

  @override
  State<TasbihTab> createState() => _TasbihTabState();
}

class _TasbihTabState extends State<TasbihTab> {
  final List<String> _phrases = [
    'سبحان الله',
    'الحمد لله',
    'لا إله إلا الله',
    'الله أكبر',
    'أستغفر الله وأتوب إليه',
  ];

  int _phrase = 0;
  int _count = 0;
  int _total = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.circle_outlined, size: 44, color: green),
            const SizedBox(height: 20),
            Text(
              _phrases[_phrase],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: gold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'إجمالي التسبيحات: $_total',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: () => setState(() {
                _count++;
                _total++;
              }),
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: green,
                  border: Border.all(color: gold, width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$_count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => setState(() => _count = 0),
                  child: const Text('تصفير العداد'),
                ),
                FilledButton(
                  onPressed: () => setState(() {
                    _phrase = (_phrase + 1) % _phrases.length;
                    _count = 0;
                  }),
                  child: const Text('تغيير الذكر'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DAILY WORSHIP TRACKER
// ============================================================

class DailyTrackerTab extends StatefulWidget {
  const DailyTrackerTab({super.key});

  @override
  State<DailyTrackerTab> createState() => _DailyTrackerTabState();
}

class _DailyTrackerTabState extends State<DailyTrackerTab> {
  final Map<String, bool> _goals = {
    'صلاة الفجر': false,
    'صلاة الظهر': false,
    'صلاة العصر': false,
    'صلاة المغرب': false,
    'صلاة العشاء': false,
    'أذكار الصباح': false,
    'أذكار المساء': false,
    'قراءة القرآن': false,
    'صلاة الوتر': false,
  };

  @override
  Widget build(BuildContext context) {
    final completed = _goals.values.where((value) => value).length;
    final progress = completed / _goals.length;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.auto_awesome, size: 36, color: gold),
                const SizedBox(height: 10),
                Text(
                  'إنجاز اليوم: $completed من ${_goals.length}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                LinearProgressIndicator(value: progress, color: green),
                const SizedBox(height: 8),
                Text('${(progress * 100).round()}%'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ..._goals.entries.map(
          (entry) => Card(
            child: CheckboxListTile(
              value: entry.value,
              title: Text(entry.key),
              activeColor: green,
              onChanged: (value) {
                setState(() => _goals[entry.key] = value ?? false);
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            for (final key in _goals.keys.toList()) {
              _goals[key] = false;
            }
          }),
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة ضبط المتابعة'),
        ),
      ],
    );
  }
}
