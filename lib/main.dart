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
      title: 'نور الإسلام الشامل',
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
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
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
    if (response.statusCode != 200) throw Exception('تعذّر جلب مواقيت الصلاة.');

    final root = jsonDecode(response.body) as Map<String, dynamic>;
    final data = root['data'] as Map<String, dynamic>;
    final raw = data['timings'] as Map<String, dynamic>;
    final result = <String, String>{};

    for (final key in names.keys) {
      final value = raw[key]?.toString() ?? '';
      final match = RegExp(r'\d{1,2}:\d{2}').firstMatch(value);
      if (match == null) throw Exception('تعذّر قراءة صلاة ${names[key]}.');
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
      tz.setLocalLocation(tz.getLocation(info));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    await plugin.initialize(
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

        await plugin.zonedSchedule(
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
    if (permission == LocationPermission.deniedForever) throw Exception('إذن الموقع مرفوض نهائياً.');
    return Geolocator.getCurrentPosition();
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
        title: const Text('نور الإسلام الشامل', style: TextStyle(fontWeight: FontWeight.bold)),
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
          const QuranFullTab(),
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
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'القرآن والصوت'),
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

// ============================================================
// QURAN & RECITERS TAB (القرآن والتفسير والقراء)
// ============================================================

class QuranFullTab extends StatefulWidget {
  const QuranFullTab({super.key});

  @override
  State<QuranFullTab> createState() => _QuranFullTabState();
}

class _QuranFullTabState extends State<QuranFullTab> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _playingSurah;
  String _selectedReciter = 'ar.alafasy';

  final Map<String, String> _reciters = {
    'ar.alafasy': 'مشاري العفاسي',
    'ar.abdulbasit': 'عبد الباسط عبد الصمد',
    'ar.minshawi': 'محمد صديق المنشاوي',
    'ar.sudais': 'عبد الرحمن السديس',
  };

  final List<Map<String, dynamic>> _surahs = [
    {'number': 1, 'name': 'الفاتحة', 'englishName': 'Al-Faatiha', 'ayahs': 7, 'revelationType': 'Meccan', 'tafseer': 'سميت بالفاتحة لأنها تفتح بها القراءة في الصلاة وهي أم الكتاب.'},
    {'number': 2, 'name': 'البقرة', 'englishName': 'Al-Baqara', 'ayahs': 286, 'revelationType': 'Medinan', 'tafseer': 'سورة مدنية عظيمة، فيها آية الكرسي وخواتيم تبين فضل الإيمان والتقوى.'},
    {'number': 18, 'name': 'الكهف', 'englishName': 'Al-Kahf', 'ayahs': 110, 'revelationType': 'Meccan', 'tafseer': 'سورة مباركة تُقرأ يوم الجمعة، تحمي من الفتن وتضم قصة أصحاب الكهف.'},
    {'number': 36, 'name': 'يس', 'englishName': 'Yaseen', 'ayahs': 83, 'revelationType': 'Meccan', 'tafseer': 'تركيز على التوحيد، البعث والنشور، وعظمة آيات الله في الكون.'},
    {'number': 56, 'name': 'الواقعة', 'englishName': 'Al-Waqi\'a', 'ayahs': 96, 'revelationType': 'Meccan', 'tafseer': 'تصف أهوال يوم القيامة وانقسام الناس إلى ثلاثة أصناف.'},
    {'number': 67, 'name': 'الملك', 'englishName': 'Al-Mulk', 'ayahs': 30, 'revelationType': 'Meccan', 'tafseer': 'السورة المنجية من عذاب القبر، الشافعة لصاحبها يوم القيامة.'},
  ];

  Future<void> _playAudio(int surahNum) async {
    try {
      final formattedNum = surahNum.toString().padLeft(3, '0');
      final url = 'https://everyayah.com/data/$_selectedReciter/128/$formattedNum.mp3';
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      setState(() {
        _isPlaying = true;
        _playingSurah = surahNum.toString();
      });
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _playingSurah = null;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('اختر القارئ:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedReciter,
                  isExpanded: true,
                  items: _reciters.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedReciter = val);
                  },
                ),
              ),
            ],
          ),
        ),
        if (_isPlaying)
          Container(
            color: green.withOpacity(0.2),
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('جاري تشغيل التلاوة الصوتية...', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                IconButton(icon: const Icon(Icons.stop_circle, color: Colors.red, size: 30), onPressed: _stopAudio),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _surahs.length,
            itemBuilder: (context, index) {
              final surah = _surahs[index];
              final isCurrentPlaying = _playingSurah == surah['number'].toString();
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: green,
                    child: Text('${surah['number']}', style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text('سورة ${surah['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${surah['revelationType'] == 'Meccan' ? 'مكية' : 'مدنية'} • ${surah['ayahs']} آية'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(isCurrentPlaying ? Icons.pause_circle : Icons.play_circle_fill, color: green, size: 32),
                        onPressed: () {
                          if (isCurrentPlaying) {
                            _stopAudio();
                   
