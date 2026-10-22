import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

const kGreen = Color(0xFF087F5B);
const kGold = Color(0xFFD7B65D);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NourIslamApp());
}

class NourIslamApp extends StatefulWidget {
  const NourIslamApp({super.key});

  @override
  State<NourIslamApp> createState() => _NourIslamAppState();
}

class _NourIslamAppState extends State<NourIslamApp> {
  bool _dark = true;

  @override
  Widget build(BuildContext context) {
    final brightness = _dark ? Brightness.dark : Brightness.light;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نور الإسلام الشامل',
      theme: ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(seedColor: kGreen, brightness: brightness),
        scaffoldBackgroundColor: _dark ? const Color(0xFF08131F) : const Color(0xFFF4F7F5),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: _dark ? const Color(0xFF101F2F) : kGreen,
          foregroundColor: Colors.white,
        ),
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: HomePage(
          dark: _dark,
          onThemeChanged: () => setState(() => _dark = !_dark),
        ),
      ),
    );
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
  int _tab = 0;
  int _cityIdx = 0;
  bool _loadingTimes = false;
  String _hijriDate = '';
  DateTime _now = DateTime.now();
  Timer? _clock;
  final AudioPlayer _adhanPlayer = AudioPlayer();
  bool _playingAdhan = false;
  String _lastAdhanAlert = '';

  final List<Map<String, dynamic>> _cities = [
    {
      'name': 'مكة المكرمة',
      'cityEn': 'Makkah',
      'countryEn': 'Saudi Arabia',
      'times': {'الفجر': '05:01', 'الشروق': '06:17', 'الظهر': '12:07', 'العصر': '15:28', 'المغرب': '17:58', 'العشاء': '19:28'},
    },
    {
      'name': 'المدينة المنورة',
      'cityEn': 'Madinah',
      'countryEn': 'Saudi Arabia',
      'times': {'الفجر': '05:03', 'الشروق': '06:21', 'الظهر': '12:09', 'العصر': '15:27', 'المغرب': '17:56', 'العشاء': '19:26'},
    },
    {
      'name': 'جدة',
      'cityEn': 'Jeddah',
      'countryEn': 'Saudi Arabia',
      'times': {'الفجر': '05:04', 'الشروق': '06:20', 'الظهر': '12:10', 'العصر': '15:31', 'المغرب': '18:01', 'العشاء': '19:31'},
    },
    {
      'name': 'الرياض',
      'cityEn': 'Riyadh',
      'countryEn': 'Saudi Arabia',
      'times': {'الفجر': '04:35', 'الشروق': '05:53', 'الظهر': '11:41', 'العصر': '14:59', 'المغرب': '17:28', 'العشاء': '18:58'},
    },
    {
      'name': 'دمشق',
      'cityEn': 'Damascus',
      'countryEn': 'Syria',
      'times': {'الفجر': '04:52', 'الشروق': '06:18', 'الظهر': '11:58', 'العصر': '15:14', 'المغرب': '17:39', 'العشاء': '19:02'},
    },
    {
      'name': 'حلب',
      'cityEn': 'Aleppo',
      'countryEn': 'Syria',
      'times': {'الفجر': '04:48', 'الشروق': '06:17', 'الظهر': '11:55', 'العصر': '15:08', 'المغرب': '17:33', 'العشاء': '18:58'},
    },
    {
      'name': 'القاهرة',
      'cityEn': 'Cairo',
      'countryEn': 'Egypt',
      'times': {'الفجر': '04:41', 'الشروق': '06:08', 'الظهر': '11:54', 'العصر': '15:11', 'المغرب': '17:39', 'العشاء': '18:57'},
    },
    {
      'name': 'عمّان',
      'cityEn': 'Amman',
      'countryEn': 'Jordan',
      'times': {'الفجر': '04:55', 'الشروق': '06:19', 'الظهر': '12:00', 'العصر': '15:17', 'المغرب': '17:42', 'العشاء': '19:03'},
    },
  ];

  Map<String, String> _currentTimings = {};

  @override
  void initState() {
    super.initState();
    _currentTimings = Map<String, String>.from(_cities[_cityIdx]['times'] as Map);
    _fetchCityTimings();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final cur = DateTime.now();
      setState(() => _now = cur);
      _checkAdhanAutoPlay(cur);
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _adhanPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchCityTimings() async {
    final c = _cities[_cityIdx];
    setState(() {
      _loadingTimes = true;
      _currentTimings = Map<String, String>.from(c['times'] as Map);
    });

    try {
      final uri = Uri.https('api.aladhan.com', '/v1/timingsByCity', {
        'city': c['cityEn'].toString(),
        'country': c['countryEn'].toString(),
        'method': '4',
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'];
        final timings = data['timings'];
        final hijri = data['date']['hijri'];

        String clean(dynamic v) => (v ?? '00:00').toString().split(' ').first;

        if (mounted) {
          setState(() {
            _currentTimings = {
              'الفجر': clean(timings['Fajr']),
              'الشروق': clean(timings['Sunrise']),
              'الظهر': clean(timings['Dhuhr']),
              'العصر': clean(timings['Asr']),
              'المغرب': clean(timings['Maghrib']),
              'العشاء': clean(timings['Isha']),
            };
            _hijriDate = '${hijri['weekday']['ar']}، ${hijri['day']} ${hijri['month']['ar']} ${hijri['year']} هـ';
          });
        }
      }
    } catch (_) {
      // Keep local fallback values if the API is unavailable.
    }

    if (mounted) {
      setState(() => _loadingTimes = false);
    }
  }

  void _checkAdhanAutoPlay(DateTime cur) {
    for (final entry in _currentTimings.entries) {
      if (entry.key == 'الشروق') continue;
      final parts = entry.value.split(':');
      if (parts.length < 2) continue;
      final hour = int.tryParse(parts[0]) ?? -1;
      final minute = int.tryParse(parts[1]) ?? -1;
      if (hour == -1 || minute == -1) continue;
      if (cur.hour == hour && cur.minute == minute && cur.second == 0) {
        final key = '${cur.day}-${entry.key}';
        if (_lastAdhanAlert != key) {
          _lastAdhanAlert = key;
          _toggleAdhanAudio(forcePlay: true);
        }
      }
    }
  }

  Future<void> _toggleAdhanAudio({bool forcePlay = false}) async {
    try {
      if (_playingAdhan && !forcePlay) {
        await _adhanPlayer.stop();
        setState(() => _playingAdhan = false);
        return;
      }

      await _adhanPlayer.stop();
      await _adhanPlayer.play(UrlSource('https://www.islamcan.com/audio/adhan/azan1.mp3'));
      setState(() => _playingAdhan = true);
    } catch (e) {
      debugPrint('Adhan audio error: $e');
    }
  }

  Map<String, String> _getNextPrayer() {
    for (final entry in _currentTimings.entries) {
      final parts = entry.value.split(':');
      if (parts.length < 2) continue;
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final prayerTime = DateTime(_now.year, _now.month, _now.day, hour, minute);
      if (prayerTime.isAfter(_now)) {
        final diff = prayerTime.difference(_now);
        final hh = diff.inHours.toString().padLeft(2, '0');
        final mm = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final ss = (diff.inSeconds % 60).toString().padLeft(2, '0');
        return {
          'name': entry.key,
          'time': entry.value,
          'countdown': '$hh:$mm:$ss',
        };
      }
    }

    final fajrParts = (_currentTimings['الفجر'] ?? '05:00').split(':');
    final nextFajr = DateTime(
      _now.year,
      _now.month,
      _now.day + 1,
      int.tryParse(fajrParts[0]) ?? 5,
      int.tryParse(fajrParts[1]) ?? 0,
    );

    final diff = nextFajr.difference(_now);
    final hh = diff.inHours.toString().padLeft(2, '0');
    final mm = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (diff.inSeconds % 60).toString().padLeft(2, '0');

    return {
      'name': 'الفجر',
      'time': _currentTimings['الفجر'] ?? '05:00',
      'countdown': '$hh:$mm:$ss',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نور الإسلام الشامل', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'صوت الأذان',
            onPressed: () => _toggleAdhanAudio(forcePlay: true),
            icon: Icon(_playingAdhan ? Icons.stop_circle : Icons.volume_up, color: kGold),
          ),
          IconButton(
            tooltip: 'تغيير المظهر',
            onPressed: widget.onThemeChanged,
            icon: Icon(widget.dark ? Icons.light_mode : Icons.dark_mode, color: kGold),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          HomePrayerTab(),
          QuranFullTab(),
          AzkarTab(),
          TasbihTab(),
          DailyTrackerTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.mosque_outlined), selectedIcon: Icon(Icons.mosque), label: 'الصلاة والأذان'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'المصحف والتفسير'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), label: 'الأذكار'),
          NavigationDestination(icon: Icon(Icons.touch_app), label: 'المسبحة'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'عباداتي'),
        ],
      ),
    );
  }
}

class HomePrayerTab extends StatefulWidget {
  const HomePrayerTab({super.key});

  @override
  State<HomePrayerTab> createState() => _HomePrayerTabState();
}

class _HomePrayerTabState extends State<HomePrayerTab> {
  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_HomePageState>();
    if (state == null) {
      return const Center(child: Text('لا توجد بيانات'));
    }

    final next = state._getNextPrayer();
    final timings = state._currentTimings;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    state._hijriDate.isNotEmpty ? state._hijriDate : '📍 اختر المدينة:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DropdownButton<int>(
                  value: state._cityIdx,
                  underline: const SizedBox(),
                  items: List.generate(
                    state._cities.length,
                    (i) => DropdownMenuItem(value: i, child: Text(state._cities[i]['name'].toString())),
                  ),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      state._cityIdx = v;
                    });
                    state._fetchCityTimings();
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF087F5B), Color(0xFF053B2B)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text('الصلاة القادمة: ${next['name']}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 8),
              Text(next['countdown']!, style: const TextStyle(color: kGold, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: Colors.black87),
                onPressed: () => state._toggleAdhanAudio(forcePlay: true),
                icon: Icon(state._playingAdhan ? Icons.stop : Icons.volume_up),
                label: Text(state._playingAdhan ? 'إيقاف صوت الأذان' : 'تشغيل صوت الأذان الآن'),
              ),
            ],
          ),
        ),
        if (state._loadingTimes)
          const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator(color: kGold)),
        const SizedBox(height: 12),
        ...timings.entries.map((entry) {
          final isNext = entry.key == next['name'];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(isNext ? Icons.notifications_active : Icons.access_time, color: isNext ? kGold : kGreen),
              title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(entry.value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isNext ? kGold : null)),
            ),
          );
        }),
      ],
    );
  }
}

class QuranFullTab extends StatefulWidget {
  const QuranFullTab({super.key});

  @override
  State<QuranFullTab> createState() => _QuranFullTabState();
}

class _QuranFullTabState extends State<QuranFullTab> {
  final AudioPlayer _player = AudioPlayer();
  String _search = '';
  int? _playingSurah;
  String _reciterServer = 'https://server8.mp3quran.net/afs';
  List<dynamic> _surahs = [];
  bool _loadingSurahs = true;

  final Map<String, String> _reciters = {
    'https://server8.mp3quran.net/afs': 'مشاري راشد العفاسي',
    'https://server7.mp3quran.net/basit': 'عبد الباسط عبد الصمد',
    'https://server12.mp3quran.net/maher': 'ماهر المعيقلي',
    'https://server11.mp3quran.net/sds': 'عبد الرحمن السديس',
    'https://server7.mp3quran.net/s_gmd': 'سعد الغامدي',
  };

  @override
  void initState() {
    super.initState();
    _loadAllSurahs();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAllSurahs() async {
    try {
      final res = await http.get(Uri.parse('https://api.alquran.cloud/v1/surah')).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'] as List<dynamic>;
        if (mounted) {
          setState(() {
            _surahs = data;
            _loadingSurahs = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _surahs = [
          {'number': 1, 'name': 'سُورَةُ ٱلْفَاتِحَةِ', 'numberOfAyahs': 7, 'revelationType': 'Meccan'},
          {'number': 2, 'name': 'سُورَةُ البَقَرَةِ', 'numberOfAyahs': 286, 'revelationType': 'Medinan'},
          {'number': 18, 'name': 'سُورَةُ الكَهْفِ', 'numberOfAyahs': 110, 'revelationType': 'Meccan'},
          {'number': 36, 'name': 'سُورَةُ يسٓ', 'numberOfAyahs': 83, 'revelationType': 'Meccan'},
          {'number': 55, 'name': 'سُورَةُ الرَّحْمَٰن', 'numberOfAyahs': 78, 'revelationType': 'Medinan'},
          {'number': 56, 'name': 'سُورَةُ الوَاقِعَةِ', 'numberOfAyahs': 96, 'revelationType': 'Meccan'},
          {'number': 67, 'name': 'سُورَةُ المُلْكِ', 'numberOfAyahs': 30, 'revelationType': 'Meccan'},
        ];
        _loadingSurahs = false;
      });
    }
  }

  Future<void> _playSurahAudio(int number) async {
    try {
      if (_playingSurah == number) {
        await _player.stop();
        setState(() => _playingSurah = null);
        return;
      }

      final fileNum = number.toString().padLeft(3, '0');
      final url = '$_reciterServer/$fileNum.mp3';
      await _player.stop();
      await _player.play(UrlSource(url));
      setState(() => _playingSurah = number);
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  void _openSurahWithTafsir(int number, String name) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: SurahReaderPage(surahNumber: number, surahName: name),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _surahs.where((surah) => surah['name'].toString().contains(_search)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              const Icon(Icons.record_voice_over, color: kGold, size: 20),
              const SizedBox(width: 8),
              const Text('القارئ:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButton<String>(
                  value: _reciterServer,
                  isExpanded: true,
                  items: _reciters.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _reciterServer = value);
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              hintText: 'ابحث في سور القرآن الكريم (114 سورة)...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
        if (_playingSurah != null)
          Container(
            color: const Color(0x33087F5B),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🎧 جاري تلاوة السورة رقم $_playingSurah', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.stop_circle, color: Colors.redAccent),
                  onPressed: () async {
                    await _player.stop();
                    setState(() => _playingSurah = null);
                  },
                ),
              ],
            ),
          ),
        Expanded(
          child: _loadingSurahs
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final surah = filtered[index];
                    final number = surah['number'] as int;
                    final name = surah['name'].toString();
                    final ayahsCount = surah['numberOfAyahs'] ?? surah['NumberOfAyahs'] ?? 0;
                    final isPlaying = _playingSurah == number;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _openSurahWithTafsir(number, name),
                        leading: CircleAvatar(
                          backgroundColor: kGreen,
                          child: Text('$number', style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text('عدد الآيات: $ayahsCount • اضغط للقراءة والتفسير'),
                        trailing: IconButton(
                          icon: Icon(isPlaying ? Icons.stop_circle : Icons.play_circle_fill, color: isPlaying ? Colors.redAccent : kGold, size: 32),
                          onPressed: () => _playSurahAudio(number),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class SurahReaderPage extends StatefulWidget {
  final int surahNumber;
  final String surahName;

  const SurahReaderPage({super.key, required this.surahNumber, required this.surahName});

  @override
  State<SurahReaderPage> createState() => _SurahReaderPageState();
}

class _SurahReaderPageState extends State<SurahReaderPage> {
  bool _loading = true;
  bool _showTafsir = true;
  List<dynamic> _ayahs = [];
  List<dynamic> _tafsir = [];

  @override
  void initState() {
    super.initState();
    _fetchSurahAndTafsir();
  }

  Future<void> _fetchSurahAndTafsir() async {
    try {
      final ayahRes = await http.get(Uri.parse('https://api.alquran.cloud/v1/surah/${widget.surahNumber}')).timeout(const Duration(seconds: 12));
      if (ayahRes.statusCode == 200) {
        final data = jsonDecode(ayahRes.body)['data'];
        final ayahs = (data is Map && data.containsKey('ayahs')) ? data['ayahs'] as List<dynamic> : <dynamic>[];
        if (mounted) {
          setState(() {
            _ayahs = ayahs;
            _loading = false;
          });
        }
      }

      final tafsirRes = await http.get(Uri.parse('https://api.quran.com/api/v4/tafsirs/by_ayah/1?language=ar')).timeout(const Duration(seconds: 12));
      if (tafsirRes.statusCode == 200) {
        final items = jsonDecode(tafsirRes.body);
        final resources = items['tafsirs'] ?? const [];
        if (resources is List && resources.isNotEmpty && mounted) {
          setState(() {
            _tafsir = resources;
          });
        }
      }
    } catch (_) {
      // fallback values
    }

    if (mounted && _ayahs.isEmpty) {
      setState(() {
        _ayahs = List.generate(10, (index) => {
          'numberInSurah': index + 1,
          'text': 'بِسْمِ ٱللّٰهِ ٱلرَّحْمٰنِ ٱلرَّحِيمِ',
        });
        _tafsir = List.generate(10, (index) => {
          'text': 'هذا مثال سريع للتفسير، ويمكن استبداله بمصدر تفسير كامل لاحقاً.',
        });
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surahName),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'سورة ${widget.surahName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: _showTafsir,
                  title: const Text('إظهار التفسير'),
                  onChanged: (value) => setState(() => _showTafsir = value),
                ),
                const SizedBox(height: 12),
                ...List.generate(_ayahs.length, (index) {
                  final ayah = _ayahs[index];
                  final ayahText = ayah['text']?.toString() ?? 'الآية ${index + 1}';
                  final tafsirText = _tafsir.isNotEmpty && index < _tafsir.length ? _tafsir[index]['text']?.toString() ?? '' : '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: kGold,
                                child: Text('${index + 1}', style: const TextStyle(color: Colors.black, fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ayahText,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 22, height: 2),
                                ),
                              ),
                            ],
                          ),
                          if (_showTafsir && tafsirText.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                tafsirText,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 14, height: 1.9),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class AzkarTab extends StatelessWidget {
  const AzkarTab({super.key});

  @override
  Widget build(BuildContext context) {
    final azkar = [
      {'title': 'أذكار الصباح', 'text': 'اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ.'},
      {'title': 'أذكار المساء', 'text': 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ، آمَنْتُ بِاللَّهِ وَكَفَيْتُ بِهِ وَقَضَيْتُ بِهِ، وَإِلَيْهِ أَرْجِعُ.'},
      {'title': 'دعاء الخروج من المنزل', 'text': 'بِسْمِ اللَّهِ، تَوَكَّلْتُ عَلَى اللَّهِ، لا حَوْلَ وَلا قُوَّةَ إِلَّا بِاللَّهِ.'},
      {'title': 'دعاء الدخول إلى المسجد', 'text': 'اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ.'},
      {'title': 'دعاء الطعام', 'text': 'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا وَجَعَلَنَا مِنَ الْمُسْلِمِينَ.'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: azkar.length,
      itemBuilder: (context, index) {
        final item = azkar[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  item['text']!,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 18, height: 1.8),
                ),
              ),
            ],
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
  int _count = 0;
  final int _goal = 33;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$_count / $_goal',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: kGreen),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => setState(() => _count++),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [kGreen, Color(0xFF0A2A24)]),
                  boxShadow: [
                    BoxShadow(color: kGreen.withOpacity(0.35), blurRadius: 20, spreadRadius: 3),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'سبحان الله',
                    style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => setState(() => _count = 0),
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => setState(() {
                    _count = _count >= _goal ? 0 : _count + 1;
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('تسبيح'),
                ),
              ],
            ),
          ],
        ),
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
  final Map<String, bool> _checks = {
    'الفجر': false,
    'الظهر': false,
    'العصر': false,
    'المغرب': false,
    'العشاء': false,
    'تلاوة القرآن': false,
    'أذكار': false,
  };

  @override
  Widget build(BuildContext context) {
    final completed = _checks.values.where((value) => value).length;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('التقدم اليومي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('$completed / ${_checks.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: kGreen)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ..._checks.keys.map((label) {
          final checked = _checks[label] ?? false;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: CheckboxListTile(
              value: checked,
              title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              onChanged: (value) => setState(() => _checks[label] = value ?? false),
              activeColor: kGreen,
            ),
          );
        }),
      ],
    );
  }
}
