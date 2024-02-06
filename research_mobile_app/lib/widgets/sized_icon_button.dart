import 'package:flutter/material.dart';

class SizedIconButton extends StatelessWidget {
  final double width;
  final IconData icon;
  final VoidCallback onPressed;
  final Color iconColor; 
  const SizedIconButton({
    Key? key,
    required this.width,
    required this.icon,
    required this.onPressed,
    this.iconColor = Colors.black, // Default color is black
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: iconColor), // Use iconColor here
      onPressed: onPressed,
      iconSize: width,
    );
  }
}
