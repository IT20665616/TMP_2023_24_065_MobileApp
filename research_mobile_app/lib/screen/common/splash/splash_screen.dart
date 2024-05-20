import 'dart:async';
import '../../../core/services/sign_in_provider.dart';
import 'package:melowave1/screen/common/login/login_screen.dart';
import 'package:melowave1/core/utils/next_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../nav/nav.dart';

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
      spm.isSignedIn == false
          ? nextScreen(context, const LoginScreen())
          : nextScreen(context, Nav());
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
