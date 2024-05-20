// Import necessary packages and files
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:melowave1/core/constants/colors.dart';
import 'package:melowave1/screen/common/favourite/fav.dart';
import 'package:melowave1/screen/common/home/home.dart';
import 'package:melowave1/screen/screen.dart';
import 'package:melowave1/screen/common/search/search.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Define the Nav class
class Nav extends StatefulWidget {
  static String routeName = '/nav';

  const Nav({
    Key? key,
  }) : super(key: key);

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
  String agePredictionResponse = "";
  String genderPredictionResponse = "";
  String weatherPredictionResponse = "";

  @override
  void initState() {
    super.initState();
    // Load responses from SharedPreferences when the widget is initialized
    loadResponsesFromPrefs();
  }

  // Function to load responses from SharedPreferences
  Future<void> loadResponsesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recommendationHubResponse =
          prefs.getString('recommendationHubResponse') ?? "";
      emotionPredictionResponse =
          prefs.getString('emotionPredictionResponse') ?? "";
      agePredictionResponse = prefs.getString('agePredictionResponse') ?? "";
      genderPredictionResponse =
          prefs.getString('genderPredictionResponse') ?? "";
      weatherPredictionResponse =
          prefs.getString('weatherPredictionResponse') ?? "";

      // Add Home, Search, Fav, and ProfileScreen pages to the list
      _pages.add(Home(
          emotionPredictionResponse: emotionPredictionResponse,
          recommendationHubResponse: recommendationHubResponse,
          agePredictionResponse: agePredictionResponse,
          genderPredictionResponse: genderPredictionResponse,
          weatherPredictionResponse: weatherPredictionResponse));
      _pages.add(Search());
      _pages.add(fav(
        userId: user.uid,
      ));
      _pages.add(ProfileScreen()); // Assuming this remains the sam
    });
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
