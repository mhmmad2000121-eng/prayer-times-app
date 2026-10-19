import 'package:flutter/material.dart';

void main() {
  runApp(const QuranPrayerApp());
}

class QuranPrayerApp extends StatelessWidget {
  const QuranPrayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نور الهدى',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F5132),
          primary: const Color(0xFF0F5132),
          secondary: const Color(0xFFD4AF37),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _tasbeehCount = 0;
  String _currentZikr = 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ';

  final List<Map<String, String>> _prayerTimes = [
    {'name': 'الفجر', 'time': '04:45 ص', 'icon': '🌅'},
    {'name': 'الشروق', 'time': '06:08 ص', 'icon': '☀️'},
    {'name': 'الظهر', 'time': '12:15 م', 'icon': '🌞'},
    {'name': 'العصر', 'time': '03:32 م', 'icon': '🌤️'},
    {'name': 'المغرب', 'time': '06:05 م', 'icon': '🌇'},
    {'name': 'العشاء', 'time': '07:35 م', 'icon': '🌙'},
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF0F5132),
          foregroundColor: Colors.white,
          centerTitle: true,
          title: const Text(
            'تطبيق القرآن ومواقيت الصلاة',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // بطاقة الصلاة القادمة الرئيسية
              _buildNextPrayerCard(),
              const SizedBox(height: 18),

              // عنوان قسم المواقيت
              const Text(
                '🕌 مواقيت الصلاة اليوم',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 10),

              // بطاقات المواقيت المصغرة
              _buildPrayerTimesGrid(),
              const SizedBox(height: 20),

              // الأقسام السريعة (القرآن والأذكار)
              const Text(
                '📖 الأقسام الرئيسية',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 10),
              _buildFeatureCards(),
              const SizedBox(height: 20),

              // المسبحة الإلكترونية التفاعلية
              _buildTasbeehSection(),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  // بطاقة مميزة للصلاة القادمة بتصميم متدرج
  Widget _buildNextPrayerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F5132), Color(0xFF198754)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F5132).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'الصلاة القادمة: صلاة العصر',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text('🌤️', style: TextStyle(fontSize: 24)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '03:32 م',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'متبقي على الأذان: ساعتان و 10 دقائق',
              style: TextStyle(color: Color(0xFFFFE082), fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // شبكة مواقيت الصلوات الخمس مع الشروق
  Widget _buildPrayerTimesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _prayerTimes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final prayer = _prayerTimes[index];
        final isNext = prayer['name'] == 'العصر';
        return Container(
          decoration: BoxDecoration(
            color: isNext ? const Color(0xFFE8F5E9) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isNext ? const Color(0xFF0F5132) : Colors.grey.shade200,
              width: isNext ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(prayer['icon']!, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                prayer['name']!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isNext ? const Color(0xFF0F5132) : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                prayer['time']!,
                style: TextStyle(
                  fontSize: 12,
                  color: isNext ? const Color(0xFF0F5132) : Colors.black54,
                  fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // بطاقات الخدمات الرئيسية
  Widget _buildFeatureCards() {
    return Column(
      children: [
        _buildServiceTile(
          icon: Icons.menu_book_rounded,
          title: 'القرآن الكريم',
          subtitle: 'تصفح السور والأجزاء مع علامة الحفظ',
          color: const Color(0xFF0F5132),
        ),
        const SizedBox(height: 10),
        _buildServiceTile(
          icon: Icons.brightness_7_rounded,
          title: 'أذكار المسلم',
          subtitle: 'أذكار الصباح، المساء، والنوم',
          color: const Color(0xFFB45309),
        ),
        const SizedBox(height: 10),
        _buildServiceTile(
          icon: Icons.explore_rounded,
          title: 'اتجاه القبلة',
          subtitle: 'تحديد بوصلة القبلة بدقة',
          color: const Color(0xFF0369A1),
        ),
      ],
    );
  }

  Widget _buildServiceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: Border.side(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم اختيار: $title')),
          );
        },
      ),
    );
  }

  // المسبحة التفاعلية
  Widget _buildTasbeehSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📿 المسبحة الإلكترونية',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
                tooltip: 'إعادة ضبط العداد',
                onPressed: () {
                  setState(() => _tasbeehCount = 0);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currentZikr,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F5132)),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              setState(() => _tasbeehCount++);
            },
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F5132), Color(0xFF2E7D32)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F5132).withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$_tasbeehCount',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'اضغط على الدائرة للتسبيح',
            style: TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
