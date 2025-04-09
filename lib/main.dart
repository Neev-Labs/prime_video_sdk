import 'package:flutter/material.dart';
import 'package:prime_video_library/ui/call_screen.dart';
import 'package:prime_video_library/ui/video_call.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart';
import 'package:permission_handler/permission_handler.dart';

class ZoomVideoSdkProvider extends StatelessWidget {
  const ZoomVideoSdkProvider({super.key});

  Future<void> checkCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
    status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    checkCameraPermission();
    var zoom = ZoomVideoSdk();
    InitConfig initConfig = InitConfig(
      domain: "zoom.us",
      enableLog: true,
    );
    zoom.initSdk(initConfig);
    return SafeArea(
      child: CallScreen(callArguments: CallArguments(
        '',
        '',
        '',
        '',
        '40',
        '',
        true,
      )),
    );
  }
}
void main() {
  runApp(MaterialApp(
    home: ZoomVideoSdkProvider(),
  ));
}