import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:prime_video_library/model/models.dart';
import 'package:prime_video_library/util/constance.dart';

import '../model/consultation_response.dart';
import '../model/consultation_check_response.dart';
import '../ui/call_screen.dart';
import '../ui/test_ads.dart';
import '../util/progress_dialog.dart';

import 'package:permission_handler/permission_handler.dart';

class Network {

  Future<bool> checkCameraPermission() async {
    var cameraStatus = await Permission.camera.status;
    var microphoneStatus = await Permission.microphone.status;
    return cameraStatus.isGranted && microphoneStatus.isGranted;
  }

  Future<String> joinConsultation(
      BuildContext context, String appointmentID, bool isProduction,
      {bool isFromWaitingRoom = false}) async {
    var permission = await checkCameraPermission();
    if (!permission) {
      return 'PSDK_E_3';
    }
    if (isProduction) {
      return 'Production not configured';
    }
    if (!isFromWaitingRoom) {
      ProgressDialog.show(context);
    }

    // 1. Call consultationCheck
    ConsultationCheckResponse? checkResponse;
    try {
      checkResponse = await consultationCheck(appointmentID, isProduction);
    } catch (e) {
      if (!isFromWaitingRoom) ProgressDialog.hide(context);
      return 'PSDK_E_500'; // Or generic error
    }

    if (checkResponse == null || checkResponse.data == null) {
      if (!isFromWaitingRoom) ProgressDialog.hide(context);
      return 'PSDK_E_2';
    }

    // 2. Check appointmentStatus
    if (checkResponse.data?.appointmentStatus != 'ACTIVE') {
      if (!isFromWaitingRoom) ProgressDialog.hide(context);
      // Logic for non-active appointment (e.g. show waiting room or error)
      // Since prompts says "if appointmentStatus IS ACTIVE then...", 
      // implied else: we might still want to show waiting room if just waiting?
      // But typically if not active it might be EXPIRED or SCHEDULED.
      // For now, let's treat as "Not Ready" -> Waiting Room (if that's the desired flow)
      // OR fail. The user said: "if the appointmentStatus is "ACTIVE" then immediately after call follwing api"
      // If not active, we probably shouldn't call the next API.
      // But we need to handle "Join" -> "Wait" flow safely.
      // Let's assume if NOT Active, we check if we should go to waiting room anyway?
      // Actually, if it's NOT active, we can't get the token/session presumably.
      // Let's redirect to waiting room if we can't proceed, effectively polling.
        if (isFromWaitingRoom) {
          return 'WAITING';
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingRoomScreen(
              appointmentId: appointmentID,
              isProduction: isProduction,
              reasonForVisit: '', // Info not available from check response in same format?
              doctorName: checkResponse.data?.doctorName,
              appointmentDate: checkResponse.data?.displayDate,
              appointmentTime: checkResponse.data?.displayTime,
            ),
          ),
        );
        return 'PSDK_E_2';
    }

    String? userId = checkResponse.data?.patientId;
    if (userId == null) {
       if (!isFromWaitingRoom) ProgressDialog.hide(context);
       return 'PSDK_E_2';
    }

    DataModel dataModel = await DataModel.create();
    
    final baseUrl = isProduction
        ? Constants.PRODUCTIONendPoint
        : Constants.UATendPoint;
    final url = '${baseUrl}consultation';

    final Map<String, dynamic> requestBody = {
      "data": {
        "browserTimeZone": "GMT%2B05:30",
        "userId": userId,
        "userType": "Patient",
        "appointmentId": appointmentID,
        "Ipaddress": dataModel.ipAddress,
        "Os": dataModel.os,
        "useragent": dataModel.userAgent 
      },
      "requestType": "201",
      "token": "d0e51850f7406e07e769addae636997621894720df8375d83bde6e582c0f8686"
    };

    final response = await http.post(Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(requestBody));

    if (!isFromWaitingRoom) {
      ProgressDialog.hide(context);
    }

    if (response.statusCode == 200) {
      ConsultationResponse consultationResponse =
          ConsultationResponse.fromJson(json.decode(response.body));

      if (consultationResponse.data?.doctorScreenstatus == null ||
          consultationResponse.data?.doctorScreenstatus !=
              'In Consultation Screen') {
        if (isFromWaitingRoom) {
          return 'WAITING';
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingRoomScreen(
              appointmentId: appointmentID,
              isProduction: isProduction,
              reasonForVisit: consultationResponse.data?.reasonforvisit,
              doctorName: consultationResponse.data?.doctorName,
              appointmentDate: consultationResponse.data?.appointmentDate,
              appointmentTime: consultationResponse.data?.appointmentTime,
            ),
          ),
        );
        return 'PSDK_E_2';
      }

      if (!(consultationResponse.data?.sessionId?.isEmpty ?? false) &&
          !(consultationResponse.data?.tokenId?.isEmpty ?? false) &&
          !(consultationResponse.data?.appointmentDate?.isEmpty ?? false)) {
        final route = MaterialPageRoute(
          builder: (context) => CallScreen(
            callArguments: CallArguments(
              consultationResponse.data!.sessionId!,
              consultationResponse.data!.tokenId!,
              '',
              '',
              '40',
              '',
              true,
            ),
          ),
        );
        final result = isFromWaitingRoom
            ? await Navigator.pushReplacement(context, route)
            : await Navigator.push(context, route);
        if (result != null) {
          return 'PSDK_1';
        } else {
          return 'PSDK_2';
        }
      } else {
        return 'PSDK_E_2';
      }
    }
    if (response.statusCode == 401) {
      return 'PSDK_E_401';
    } else if (response.statusCode == 500) {
      return 'PSDK_E_500';
    } else {
      return 'PSDK_E_408';
    }
  }

  Future<ConsultationCheckResponse?> consultationCheck(
      String appointmentID, bool isProduction) async {
    final baseUrl = isProduction
        ? Constants.PRODUCTIONendPoint
        : Constants.UATendPoint;
    final url = '${baseUrl}consultationcheck';

    final Map<String, dynamic> body = {
      "token": "d0e51850f7406e07e769addae636997621894720df8375d83bde6e582c0f8686",
      "version": "2.0",
      "data": {
        "browserTimeZone": "GMT%2B05:30",
        "token": appointmentID
      },
      "requestType": 1077
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return ConsultationCheckResponse.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint("consultationCheck error: $e");
    }
    return null;
  }

}
