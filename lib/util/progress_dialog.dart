import 'package:flutter/material.dart';

class ProgressDialog {
  // Context of the dialog route itself, so hide() pops exactly that route and
  // never a page belonging to the host app.
  static BuildContext? _dialogContext;

  static void show(BuildContext context) {
    if (_dialogContext != null) return; // already showing
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false, // Prevents closing on tap
      builder: (dialogContext) {
        _dialogContext = dialogContext;
        return const AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    ).then((_) => _dialogContext = null);
  }

  static void hide(BuildContext context) {
    final dialogContext = _dialogContext;
    _dialogContext = null;
    if (dialogContext == null || !dialogContext.mounted) return;
    Navigator.of(dialogContext).pop();
  }
}
