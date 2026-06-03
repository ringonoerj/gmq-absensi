import 'dart:async';
import 'package:flutter/material.dart';

class GreetingCard extends StatefulWidget {
  final String userName;

  const GreetingCard({super.key, required this.userName});

  @override
  State<GreetingCard> createState() => _GreetingCardState();
}

class _GreetingCardState extends State<GreetingCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _quoteIndex = 0;
  Timer? _timer;

  final List<String> _quotes = [
    '“Barangsiapa yang menempuh suatu jalan untuk mencari ilmu, maka Allah akan memudahkan baginya jalan menuju surga.” — HR. Muslim',
    '“Ilmu itu bukan yang dihafal, tetapi yang memberi manfaat.” — Imam Syafi\'i',
    '“Menuntut ilmu adalah kewajiban bagi setiap muslim.” — HR. Ibnu Majah',
    '“Jika seseorang bepergian dengan tujuan mencari ilmu, maka ia berada di jalan Allah sampai ia kembali.” — HR. Tirmidzi',
    '“Sebaik-baik kalian adalah orang yang mempelajari Al-Qur\'an dan mengajarkannya.” — HR. Bukhari',
    '“Belajarlah kamu sekalian, dan mengajarlah kamu sekalian, dan hormatilah guru-gurumu.” — HR. Ath-Thabrani',
    '“Kelebihan seorang alim dibanding seorang abid (ahli ibadah) seperti kelebihan bulan purnama atas seluruh bintang-bintang.” — HR. Abu Dawud',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    // Rotate quotes every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _animationController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _quoteIndex = (_quoteIndex + 1) % _quotes.length;
            });
            _animationController.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour >= 4 && hour < 10) {
      greeting = 'Selamat Pagi 🌅';
    } else if (hour >= 10 && hour < 15) {
      greeting = 'Selamat Siang ☀️';
    } else if (hour >= 15 && hour < 18) {
      greeting = 'Selamat Sore 🌇';
    } else {
      greeting = 'Selamat Malam 🌌';
    }
    return "Assalamu'alaikum, $greeting";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
              ? [const Color(0xFF0F5E59), const Color(0xFF1E293B)]
              : [const Color(0xFF0F766E), const Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black45 : Colors.teal.withOpacity(0.3)),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getGreeting(),
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.userName,
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.2), height: 1),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Text(
                  _quotes[_quoteIndex],
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Color(0xE6FFFFFF),
                    height: 1.4,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
