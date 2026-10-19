import 'package:flutter/material.dart';

void main() {
  runApp(const MuslimCompanionApp());
}

class MuslimCompanionApp extends StatelessWidget {
  const MuslimCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'رفيق المسلم',
      theme: ThemeData(
        primaryColor: const Color(0xFF0D5C46),
        scaffoldBackgroundColor: const Color(0xFFF4F7F5),
      ),
      home: const HomeContainerScreen(),
    );
  }
}

class HomeContainerScreen extends StatefulWidget {
  const HomeContainerScreen({super.key});

  @override
  State<HomeContainerScreen> createState() => _HomeContainerScreenState();
}

class _HomeContainerScreenState extends State<HomeContainerScreen> {
  int _activeTab = 0;
  int _counter = 0;
  int _zikrIndex = 0;

  final List<String> _tasbeehPhrases = [
    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
    'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
    'لَا إِلَهَ إِلَّا اللَّهُ',
    'اللَّهُ أَكْبَرُ كَبِيرًا',
    'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
  ];

  final List<Map<String, String>> _dailyPrayers = [
    {'title': 'الفجر', 'clock': '04:48 ص', 'symbol': '🌌'},
    {'title': 'الشروق', 'clock': '06:10 ص', 'symbol': '🌅'},
    {'title': 'الظهر', 'clock': '12:18 م', 'symbol': '☀️'},
    {'title': 'العصر', 'clock': '03:35 م', 'symbol': '🌤️'},
    {'title': 'المغرب', 'clock': '06:08 م', 'symbol': '🌇'},
    {'title': 'العشاء', 'clock': '07:38 م', 'symbol': '🌙'},
  ];

  final List<Map<String, String>> _surahList = [
    {'num': '1', 'name': 'سورة الفاتحة', 'type': 'مكية - 7 آيات'},
    {'num': '2', 'name': 'سورة البقرة', 'type': 'مدنية - 286 آية'},
    {'num': '18', 'name': 'سورة الكهف', 'type': 'مكية - 110 آيات'},
    {'num': '36', 'name': 'سورة يس', 'type': 'مكية - 83 آية'},
    {'num': '55', 'name': 'سورة الرحمن', 'type': 'مدنية - 78 آية'},
    {'num': '67', 'name': 'سورة الملك', 'type': 'مكية - 30 آية'},
  ];

  final List<Map<String, String>> _azkarItems = [
    {
      'category': 'أذكار الصباح',
      'body': 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ.'
    },
    {
      'category': 'أذكار المساء',
      'body': 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ.'
    },
    {
      'category': 'سيد الاستغفار',
      'body': 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D5C46),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          title: const Text(
            'رفيق المسلم - الصلاة والقرآن',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        body: _buildCurrentTabContent(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _activeTab,
          onTap: (idx) {
            setState(() {
              _activeTab = idx;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF0D5C46),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.access_time_filled), label: 'المواقيت'),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book_rounded), label: 'القرآن'),
            BottomNavigationBarItem(icon: Icon(Icons.wb_sunny_rounded), label: 'الأذكار'),
            BottomNavigationBarItem(icon: Icon(Icons.touch_app_rounded), label: 'المسبحة'),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    if (_activeTab == 1) {
      return _buildQuranScreen();
    } else if (_activeTab == 2) {
      return _buildAzkarScreen();
    } else if (_activeTab == 3) {
      return _buildTasbeehScreen();
    }
    return _buildPrayerTimesScreen();
  }

  // 1. شاشة مواقيت الصلاة
  Widget _buildPrayerTimesScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D5C46), Color(0xFF1B8A6B)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: const [
                Text(
                  'الصلاة القادمة: صلاة العصر',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                SizedBox(height: 8),
                Text(
                  '03:35 م',
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'حافظوا على الصلوات والصلاة الوسطى',
                  style: TextStyle(color: Color(0xFFFFD54F), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'جدول المواقيت اليومية',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 10),
          ..._dailyPrayers.map((item) {
            final bool highlight = item['title'] == 'العصر';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: highlight ? const Color(0xFFE6F4EA) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: highlight ? const Color(0xFF0D5C46) : const Color(0xFFE5E7EB),
                  width: highlight ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(item['symbol'] ?? '', style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Text(
                        item['title'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: highlight ? const Color(0xFF0D5C46) : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    item['clock'] ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: highlight ? const Color(0xFF0D5C46) : Colors.black54,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 2. شاشة القرآن الكريم
  Widget _buildQuranScreen() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _surahList.length,
      itemBuilder: (context, index) {
        final surah = _surahList[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE6F4EA),
              child: Text(
                surah['num'] ?? '',
                style: const TextStyle(color: Color(0xFF0D5C46), fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              surah['name'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(surah['type'] ?? ''),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          ),
        );
      },
    );
  }

  // 3. شاشة الأذكار
  Widget _buildAzkarScreen() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _azkarItems.length,
      itemBuilder: (context, index) {
        final zikr = _azkarItems[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                zikr['category'] ?? '',
                style: const TextStyle(
                  color: Color(0xFF0D5C46),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Divider(height: 18),
              Text(
                zikr['body'] ?? '',
                style: const TextStyle(fontSize: 15, height: 1.7, color: Colors.black87),
              ),
            ],
          ),
        );
      },
    );
  }

  // 4. شاشة المسبحة الإلكترونية
  Widget _buildTasbeehScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                _tasbeehPhrases[_zikrIndex],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D5C46),
                ),
              ),
            ),
            const SizedBox(height: 30),
            GestureDetector(
              onTap: () {
                setState(() {
                  _counter++;
                });
              },
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D5C46), Color(0xFF1B8A6B)],
                  ),
                ),
                child: Center(
                  child: Text(
                    '$_counter',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _counter = 0;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('تصفير العداد'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _zikrIndex = (_zikrIndex + 1) % _tasbeehPhrases.length;
                      _counter = 0;
                    });
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('تغيير الذكر'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
