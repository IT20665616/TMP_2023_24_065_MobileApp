// Import necessary packages and files
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:research_mobile_app/config/theme/theme.dart';
import 'package:research_mobile_app/screen/screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Define the Nav class
class Nav extends StatefulWidget {
  static String routeName = '/nav';

  const Nav({
    Key? key,   }) : super(key: key);

  @override
  State<Nav> createState() => _NavState();
}

// Define the state of the Nav class
class _NavState extends State<Nav> {
  // Get the current user
  final user = FirebaseAuth.instance.currentUser!;
  // Initialize variables for pages and current index
  final List<Widget> _pages = [];
  int _currentIndex = 0;
  // Initialize variables for storing response data
  String recommendationHubResponse = "";
  String emotionPredictionResponse = "";

  @override
  void initState() {
    super.initState();
    // Load responses from SharedPreferences when the widget is initialized
  }



  @override
  Widget build(BuildContext context) {
    // Build the scaffold with an IndexedStack and BottomNavigationBar
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: _onTabTapped,
        currentIndex: _currentIndex,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.colorPrimary,
        unselectedItemColor: AppColors.colorTint600,
        selectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(
              FontAwesomeIcons.home,
              size: 21,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              FontAwesomeIcons.searchPlus,
              size: 21,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              FontAwesomeIcons.heartCirclePlus,
              size: 21,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              FontAwesomeIcons.userTie,
              size: 21,
            ),
            label: '',
          ),
        ],
      ),
    );
  }

  // Function to handle tab selection
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
}
