import 'package:flutter/material.dart';

class ProgressDialog {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents closing on tap
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  static void hide(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}
