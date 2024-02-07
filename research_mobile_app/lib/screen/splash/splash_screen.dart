import 'dart:async';
import '../../../provider/sign_in_provider.dart';
import 'package:research_mobile_app/screen/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  static String routeName = '/splash';
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // init state
  @override
  void initState() {
    final spm = context.read<SignInProvider>();
    super.initState();
    // create a timer of 2 seconds
    Timer(const Duration(seconds: 2), () {
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
            child: Image(
          image: AssetImage("assets/logo.png"),
          height: 200,
          width: 200,
        )),
      ),
    );
  }
}
