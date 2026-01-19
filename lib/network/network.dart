import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:prime_video_library/model/consultation_model.dart';
import 'package:prime_video_library/model/models.dart';
import 'package:prime_video_library/ui/zoom_video_call_screen.dart';
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
      {bool isFromWaitingRoom = false,
      Function(ConsultationResponse)? onConsultationFetch}) async {
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
      return 'PSDK_E_6';
    }

    // 2. Check appointmentStatus
    if (checkResponse.data?.appointmentStatus == 'EXPIRED') {
      if (!isFromWaitingRoom) ProgressDialog.hide(context);
      await _showStatusDialog(
        context,
        title: "Consultation Expired",
        date: checkResponse.data?.displayDate,
        time: checkResponse.data?.displayTime,
        isEarly: false,
      );
      return 'PSDK_E_4';
    }
    if (checkResponse.data?.appointmentStatus == 'UPCOMING') {
      if (!isFromWaitingRoom) ProgressDialog.hide(context);
      await _showStatusDialog(
        context,
        title: "You’re Early!",
        date: checkResponse.data?.displayDate,
        time: checkResponse.data?.displayTime,
        isEarly: true,
      );
      return 'PSDK_E_5';
    }

    String? userId = checkResponse.data?.patientId;
    if (userId == null) {
       if (!isFromWaitingRoom) ProgressDialog.hide(context);
       return 'PSDK_E_6';
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

    debugPrint('API Request: $url');
    debugPrint('Request Body: ${json.encode(requestBody)}');

    final response = await http.post(Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(requestBody));

    if (!isFromWaitingRoom) {
      ProgressDialog.hide(context);
    }
    
    debugPrint('API Response [${response.statusCode}]: ${response.body}');

    if (response.statusCode == 200) {
      ConsultationResponse consultationResponse =
      ConsultationResponse.fromJson(json.decode(response.body));

      if (onConsultationFetch != null) {
        onConsultationFetch(consultationResponse);
      }

      if (consultationResponse.data?.doctorScreenstatus == null ||
          consultationResponse.data?.doctorScreenstatus !=
              'In Consultation Screen') {
        if (isFromWaitingRoom) {
          return 'WAITING';
        }
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                WaitingRoomScreen(
                  appointmentId: appointmentID,
                  isProduction: isProduction,
                  reasonForVisit: consultationResponse.data?.reasonforvisit,
                  doctorName: consultationResponse.data?.doctorName,
                  appointmentDate: consultationResponse.data?.appointmentDate,
                  appointmentTime: consultationResponse.data?.appointmentTime,
                ),
          ),
        );
        // If we return from waiting room (either user left or call finished via replacement), 
        // we should exit this flow.
        return result as String? ?? 'PSDK_2';
      } else {
      if (!(consultationResponse.data?.sessionId?.isEmpty ?? false) &&
          !(consultationResponse.data?.tokenId?.isEmpty ?? false) &&
          !(consultationResponse.data?.appointmentDate?.isEmpty ?? false)) {
        final route = MaterialPageRoute(
          builder: (context) =>
              ZoomVideoCallScreen(
                  consultationModel: ConsultationModel.fromSessionIdAndToken(
                      sessionId: consultationResponse.data!.sessionId!,
                      patientToken: consultationResponse.data!.tokenId!,
                      doctorName: consultationResponse.data!.doctorName,
                      doctorImage: "",
                      status: ""
                  )
              )
              // CallScreen(
              //   callArguments: CallArguments(
              //     consultationResponse.data!.sessionId!,
              //     consultationResponse.data!.tokenId!,
              //     '',
              //     '',
              //     '40',
              //     '',
              //     true,
              //   ),
              // ),
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

    debugPrint('API Request: $url');
    debugPrint('Request Body: ${json.encode(body)}');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(body),
      );
      
      debugPrint('API Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200) {
        return ConsultationCheckResponse.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint("consultationCheck error: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> getAds(bool isProduction) async {
    final baseUrl = isProduction
        ? Constants.PRODUCTIONendPoint
        : Constants.UATendPoint;
    final url = '${baseUrl}getads';

    final Map<String, dynamic> body = {
      "token": "d0e51850f7406e07e769addae636997621894720df8375d83bde6e582c0f8686",
      "data": {
        "clinicId": "144" 
      },
      "requestType": 0
    };

    debugPrint('API Request: $url');
    debugPrint('Request Body: ${json.encode(body)}');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(body),
      );

      debugPrint('API Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint("getAds error: $e");
    }
    return null;
  }

  Future<void> _showStatusDialog(
    BuildContext context, {
    required String title,
    String? date,
    String? time,
    required bool isEarly,
  }) {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF9E6), // Light yellow
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 32),
              ),
              const SizedBox(height: 16),
              // Title
              Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              // Message
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                      color: Colors.black54, fontSize: 14, height: 1.5),
                  children: [
                    TextSpan(
                        text: "This appointment " +
                            (isEarly ? "is" : "was") +
                            " scheduled for "),
                    TextSpan(
                      text: "${date ?? ''}, ${time ?? ''}.",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    TextSpan(
                        text: isEarly
                            ? "\nPlease wait until the scheduled time for the doctor to join."
                            : "\nPlease contact the hospital to reschedule."),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6), // Purple
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Ok",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
