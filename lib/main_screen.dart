import 'package:flutter/material.dart';
import 'package:insta_downloader/constants/app_colors.dart';
import 'package:insta_downloader/pages/Home%20Page/homepage.dart';
import 'package:insta_downloader/pages/browser_page.dart';
import 'package:insta_downloader/pages/downloads_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const BrowserPage(),
    const DownloadsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(50),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.iconColor,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          backgroundColor: Colors.white,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ana Sayfa'),
            BottomNavigationBarItem(icon: Icon(Icons.web), label: 'Tarayıcı'),
            BottomNavigationBarItem(
              icon: Icon(Icons.download_done),
              label: 'İndirilenler',
            ),
          ],
        ),
      ),
    );
  }
}
