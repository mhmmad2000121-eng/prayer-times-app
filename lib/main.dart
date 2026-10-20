import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NoorAlIslamApp());
}

class NoorAlIslamApp extends StatefulWidget {
  const NoorAlIslamApp({super.key});

  @override
  State<NoorAlIslamApp> createState() => _NoorAlIslamAppState();
}

class _NoorAlIslamAppState extends State<NoorAlIslamApp> {
  bool _isDarkMode = true;

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF4F7F5),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0B6E4F),
        secondary: Color(0xFFD4AF37),
        surface: Colors.white,
        onPrimary: Colors.white,
        onSurface: Color(0xFF1C2826),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B6E4F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF091018),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFD4AF37),
        secondary: Color(0xFF109868),
        surface: Color(0xFF131F2C),
        onPrimary: Color(0xFF091018),
        onSurface: Color(0xFFF2F5F8),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D1722),
        foregroundColor: Color(0xFFD4AF37),
        elevation: 0,
        centerTitle: true,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نور الإسلام الاحترافي',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: MainHomeScreen(
        isDarkMode: _isDarkMode,
        onToggleTheme: () => setState(() => _isDarkMode = !_isDarkMode),
      ),
    );
  }
}

class CityInfo {
  final String nameAr;
  final String countryAr;
  final double lat;
  final double lng;
  final Map<String, String> timings;

  const CityInfo(
    this.nameAr,
    this.countryAr,
    this.lat,
    this.lng,
    this.timings,
  );
}

class MainHomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const MainHomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _tabIndex = 0;
  int _cityIndex = 0;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  int _bookmarkSurahNum = 18;
  String _bookmarkSurahName = 'الكهف';
  int _bookmarkAyah = 10;

  final Map<String, bool> _worshipTracker = {
    'صلاة الفجر في وقتها': true,
    'أذكار الصباح': true,
    'صلاة الضحى': false,
    'صلاة الظهر والسنن الرواتب': true,
    'صلاة العصر': false,
    'أذكار المساء': false,
    'صلاة المغرب والسنن': false,
    'صلاة العشاء والوتر': false,
    'الورد القرآني اليومي': true,
    'قيام الليل والاستغفار': false,
    'الصدقة أو الكلمة الطيبة': false,
  };

  static const List<CityInfo> _cities = [
    CityInfo('دمشق', 'سوريا', 33.5138, 36.2765, {
      'الفجر': '04:52',
      'الشروق': '06:18',
      'الظهر': '11:58',
      'العصر': '15:14',
      'المغرب': '17:39',
      'العشاء': '19:02',
    }),
    CityInfo('حلب', 'سوريا', 36.2021, 37.1343, {
      'الفجر': '04:48',
      'الشروق': '06:17',
      'الظهر': '11:55',
      'العصر': '15:08',
      'المغرب': '17:33',
      'العشاء': '18:58',
    }),
    CityInfo('مكة المكرمة', 'السعودية', 21.4225, 39.8262, {
      'الفجر': '05:01',
      'الشروق': '06:17',
      'الظهر': '12:07',
      'العصر': '15:28',
      'المغرب': '17:58',
      'العشاء': '19:28',
    }),
    CityInfo('المدينة المنورة', 'السعودية', 24.4672, 39.6112, {
      'الفجر': '05:03',
      'الشروق': '06:21',
      'الظهر': '12:09',
      'العصر': '15:27',
      'المغرب': '17:56',
      'العشاء': '19:26',
    }),
    CityInfo('الرياض', 'السعودية', 24.7136, 46.6753, {
      'الفجر': '04:35',
      'الشروق': '05:53',
      'الظهر': '11:41',
      'العصر': '14:59',
      'المغرب': '17:28',
      'العشاء': '18:58',
    }),
    CityInfo('جدة', 'السعودية', 21.5433, 39.1728, {
      'الفجر': '05:04',
      'الشروق': '06:20',
      'الظهر': '12:10',
      'العصر': '15:31',
      'المغرب': '18:01',
      'العشاء': '19:31',
    }),
    CityInfo('القاهرة', 'مصر', 30.0444, 31.2357, {
      'الفجر': '04:41',
      'الشروق': '06:08',
      'الظهر': '11:54',
      'العصر': '15:11',
      'المغرب': '17:39',
      'العشاء': '18:57',
    }),
    CityInfo('عمّان', 'الأردن', 31.9454, 35.9284, {
      'الفجر': '04:55',
      'الشروق': '06:19',
      'الظهر': '12:00',
      'العصر': '15:17',
      'المغرب': '17:42',
      'العشاء': '19:03',
    }),
  ];

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String _formatHijriDate(DateTime date) {
    const months = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الآخر',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];
    const days = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    double jd = (date.millisecondsSinceEpoch / 86400000.0) + 2440587.5;
    double l = (jd - 1948440 + 10632).floorToDouble();
    double n = ((l - 1) / 10631).floorToDouble();
    l = l - 10631 * n + 354;
    double j = (((10985 - l) / 5316).floorToDouble()) *
            (((50 * l) / 17719).floorToDouble()) +
        ((l / 5670).floorToDouble()) * (((43 * l) / 15238).floorToDouble());
    l = l -
        (((30 - j) / 15).floorToDouble()) *
            (((17719 * j) / 50).floorToDouble()) -
        ((j / 16).floorToDouble()) * (((15238 * j) / 43).floorToDouble()) +
        29;
    int m = ((24 * l) / 709).floor();
    int d = (l - ((709 * m) / 24).floor()).round();
    int y = (30 * n + j - 30).round();
    return '${days[(date.weekday - 1).clamp(0, 6)]}، $d ${months[(m - 1).clamp(0, 11)]} $y هـ';
  }

  Map<String, String> _getNextPrayer() {
    final timings = _cities[_cityIndex].timings;
    const order = ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    DateTime? nextDt;
    String nextName = 'الفجر';
    String nextStr = timings['الفجر'] ?? '05:00';

    for (final name in order) {
      final raw = timings[name] ?? '00:00';
      final p = raw.split(':');
      if (p.length < 2) continue;
      final cand = DateTime(
        _now.year,
        _now.month,
        _now.day,
        int.tryParse(p[0]) ?? 0,
        int.tryParse(p[1]) ?? 0,
      );
      if (cand.isAfter(_now)) {
        nextDt = cand;
        nextName = name;
        nextStr = raw;
        break;
      }
    }

    if (nextDt == null) {
      final raw = timings['الفجر'] ?? '05:00';
      final p = raw.split(':');
      nextDt = DateTime(
        _now.year,
        _now.month,
        _now.day + 1,
        int.tryParse(p[0]) ?? 5,
        int.tryParse(p.length > 1 ? p[1] : '0') ?? 0,
      );
    }

    final diff = nextDt.difference(_now);
    final hh = diff.inHours.toString().padLeft(2, '0');
    final mm = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return {'name': nextName, 'time': nextStr, 'countdown': '$hh:$mm:$ss'};
  }

  double _qiblaDegree() {
    final c = _cities[_cityIndex];
    const kLat = 21.4225 * math.pi / 180.0;
    const kLng = 39.8262 * math.pi / 180.0;
    final lat = c.lat * math.pi / 180.0;
    final lng = c.lng * math.pi / 180.0;
    final dLng = kLng - lng;
    final b = math.atan2(
          math.sin(dLng),
          math.cos(lat) * math.tan(kLat) - math.sin(lat) * math.cos(dLng),
        ) *
        180.0 /
        math.pi;
    return (b + 360.0) % 360.0;
  }

  void _showAdhanDialog(String prayerName, String prayerTime) {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    final city = _cities[_cityIndex];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.mosque, color: Color(0xFFD4AF37)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'تنبيه الأذان',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'موعد صلاة $prayerName ($prayerTime) بتوقيت ${city.nameAr}.\nبادر إلى الصلاة وتقبل الله طاعتكم.',
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildPrayerAndHomeTab(),
      QuranFullTab(
        bookmarkedSurahNum: _bookmarkSurahNum,
        bookmarkedSurahName: _bookmarkSurahName,
        bookmarkedAyah: _bookmarkAyah,
        onSaveBookmark: (sNum, sName, ayah) {
          setState(() {
            _bookmarkSurahNum = sNum;
            _bookmarkSurahName = sName;
            _bookmarkAyah = ayah;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حفظ علامة القراءة: سورة $sName - مقطع $ayah'),
            ),
          );
        },
      ),
      const HisnAlMuslimTab(),
      const ElectronicTasbihTab(),
      MoreWorshipAndNamesTab(
        tracker: _worshipTracker,
        onToggle: (k, v) => setState(() => _worshipTracker[k] = v),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 20),
            SizedBox(width: 8),
            Text(
              'نور الإسلام الاحترافي',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تجربة تنبيه الأذان',
            onPressed: () {
              final next = _getNextPrayer();
              _showAdhanDialog(next['name']!, next['time']!);
            },
            icon: const Icon(Icons.notifications_active_outlined),
          ),
          IconButton(
            tooltip: 'تبديل المظهر',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isDarkMode
                  ? Icons.wb_sunny_rounded
                  : Icons.nightlight_round,
              color: const Color(0xFFD4AF37),
            ),
          ),
        ],
      ),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mosque_outlined),
            selectedIcon: Icon(Icons.mosque),
            label: 'المواقيت',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'المصحف',
          ),
          NavigationDestination(
            icon: Icon(Icons.volunteer_activism_outlined),
            selectedIcon: Icon(Icons.volunteer_activism),
            label: 'الأذكار',
          ),
          NavigationDestination(
            icon: Icon(Icons.touch_app_outlined),
            selectedIcon: Icon(Icons.touch_app),
            label: 'المسبحة',
          ),
          NavigationDestination(
            icon: Icon(Icons.stars_outlined),
            selectedIcon: Icon(Icons.stars),
            label: 'العبادات',
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerAndHomeTab() {
    final city = _cities[_cityIndex];
    final next = _getNextPrayer();
    final qibla = _qiblaDegree().toStringAsFixed(1);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // شريط التاريخ الهجري واختيار المدينة
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x59D4AF37)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFFD4AF37),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatHijriDate(_now),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _cityIndex,
                  onChanged: (idx) {
                    if (idx != null) {
                      setState(() => _cityIndex = idx);
                    }
                  },
                  items: List.generate(
                    _cities.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${_cities[i].nameAr} (${_cities[i].countryAr})',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // بطاقة الصلاة القادمة والعداد التنازلي بالثواني
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B6E4F), Color(0xFF073B2A)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Text(
                'الصلاة القادمة في ${city.nameAr}: ${next['name']}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                next['countdown']!,
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'موعد الأذان: ${next['time']} • اتجاه القبلة: $qibla°',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // جدول مواقيت الصلاة اليومية
        const Text(
          '🕌 جدول مواقيت الصلاة',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...city.timings.entries.map((entry) {
          final isNext = entry.key == next['name'];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: isNext
                  ? const Color(0x26109868)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isNext
                    ? const Color(0xFFD4AF37)
                    : const Color(0x33888888),
                width: isNext ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isNext ? Icons.notifications_active : Icons.access_time,
                      color: isNext
                          ? const Color(0xFFD4AF37)
                          : const Color(0xFF109868),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isNext ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isNext ? const Color(0xFFD4AF37) : null,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// 2. تبويب المصحف الشريف والعلامة المرجعية
class QuranFullTab extends StatefulWidget {
  final int bookmarkedSurahNum;
  final String bookmarkedSurahName;
  final int bookmarkedAyah;
  final void Function(int, String, int) onSaveBookmark;

  const QuranFullTab({
    super.key,
    required this.bookmarkedSurahNum,
    required this.bookmarkedSurahName,
    required this.bookmarkedAyah,
    required this.onSaveBookmark,
  });

  @override
  State<QuranFullTab> createState() => _QuranFullTabState();
}

class _QuranFullTabState extends State<QuranFullTab> {
  String _searchQuery = '';

  static const List<Map<String, dynamic>> _surahs = [
    {'num': 1, 'name': 'الفاتحة', 'type': 'مكية', 'ayas': 7},
    {'num': 2, 'name': 'البقرة', 'type': 'مدنية', 'ayas': 286},
    {'num': 3, 'name': 'آل عمران', 'type': 'مدنية', 'ayas': 200},
    {'num': 4, 'name': 'النساء', 'type': 'مدنية', 'ayas': 176},
    {'num': 18, 'name': 'الكهف', 'type': 'مكية', 'ayas': 110},
    {'num': 36, 'name': 'يس', 'type': 'مكية', 'ayas': 83},
    {'num': 55, 'name': 'الرحمن', 'type': 'مدنية', 'ayas': 78},
    {'num': 56, 'name': 'الواقعة', 'type': 'مكية', 'ayas': 96},
    {'num': 67, 'name': 'الملك', 'type': 'مكية', 'ayas': 30},
    {'num': 112, 'name': 'الإخلاص', 'type': 'مكية', 'ayas': 4},
    {'num': 113, 'name': 'الفلق', 'type': 'مكية', 'ayas': 5},
    {'num': 114, 'name': 'الناس', 'type': 'مكية', 'ayas': 6},
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _surahs
        .where((s) => s['name'].toString().contains(_searchQuery))
        .toList();

    return Column(
      children: [
        // بطاقة علامة الختمة المحفوظة
        Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0B6E4F),
     
