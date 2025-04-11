import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:prime_video_library/model/models.dart';
import 'package:prime_video_library/util/constance.dart';

import '../model/consultation_response.dart';
import '../ui/call_screen.dart';
import '../util/progress_dialog.dart';

import 'package:permission_handler/permission_handler.dart';

class Network {

  Future<bool> checkCameraPermission() async {
    var cameraStatus = await Permission.camera.status;
    var microphoneStatus = await Permission.microphone.status;
    return cameraStatus.isGranted && microphoneStatus.isGranted;
  }

  Future<String> joinConsultation(
      BuildContext context, String appointmentID, bool isProduction) async {
    var permission = await checkCameraPermission();
    if (!permission) {
      return 'PSDK_E_3';
    }
    if(isProduction) {
      return 'Production not configured';
    }
    ProgressDialog.show(context);
    DataModel dataModel = await DataModel.create();
    ConsultationRequestModel consultationRequestModel =
    ConsultationRequestModel(
        consultationId: appointmentID,
        userType: 'Patient',
        browserTimeZone: 'GMT%2D05:30',
        currency: 'INR',
        accessCountry: 'IN',
        todayRate: '');
    consultationRequestModel.os = dataModel.os;
    consultationRequestModel.ipAddress = dataModel.ipAddress;
    consultationRequestModel.userAgent = dataModel.userAgent;
    RequestDataModel requestModel = RequestDataModel(
        token:
        'fcfb70e15b304a88af137f8a0906e65c0bc7f1d662e6aed146f34c0e975d6756',
        C2MDVerificationToken: '',
        requestType: '400',
        dataModel: consultationRequestModel);
    final baseUrl = isProduction
        ? Constants.PRODUCTIONendPoint
        : Constants.UATendPoint;
    final url = '${baseUrl}consultation';
    final response = await http.post(Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(requestModel.toJson()));
    ProgressDialog.hide(context);

    if (response.statusCode == 200) {
      ConsultationResponse consultationResponse =
      ConsultationResponse.fromJson(json.decode(response.body));
      if (!(consultationResponse.data?.sessionId?.isEmpty ?? false) &&
          !(consultationResponse.data?.tokenId?.isEmpty ?? false) &&
          !(consultationResponse.data?.appointmentDate?.isEmpty ?? false)) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
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
          ),
        );
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
}
