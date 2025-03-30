import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';

import '../ui/login.dart';
class Common {
  Future<String> getIPAddress() async {
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (var interface in interfaces) {
        for (var address in interface.addresses) {
          print('Interface: ${interface.name}');
          print('IP Address: ${address.address}');
          return address.address;
        }
      }
    } catch (e) {
      return '';
    }
    return '';
  }

  void openLibraryScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Login()),
    );
  }

  String getGMTOffset() {
    final DateTime now = DateTime.now();
    final Duration offset = now.timeZoneOffset;
    final int hours = offset.inHours;
    final int minutes = offset.inMinutes.remainder(60);
    String gmtOffset =
        'GMT${hours >= 0 ? '+' : ''}$hours:${minutes.toString().padLeft(2, '0')}';
    gmtOffset = gmtOffset.replaceAll('+', '%2B').replaceAll('-', '%2D');
    return gmtOffset;
  }

  Future<String> getOSVersion() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return 'Android ${androidInfo.version.release}(${androidInfo.version.sdkInt})';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.systemVersion;
    } else {
      return '';
    }
  }

  Future<String> getPhoneModel() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.model;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.utsname.machine;
    } else {
      return '';
    }
  }
}
