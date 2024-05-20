import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:melowave1/core/utils/app_bar.dart';
import 'components/body.dart';

class ProfileScreen extends StatelessWidget {
  final user = FirebaseAuth.instance.currentUser;

  static String routeName = '/profile';

  ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Profile",
        leadingImage: null, // Pass the user's photo URL directly
        actionImage: null,
        onLeadingPressed: () {
          print("Leading icon pressed");
        },
        onActionPressed: () {
          print("Action icon pressed");
        },
      ),
      body: Body(user: user),
    );
  }
}
