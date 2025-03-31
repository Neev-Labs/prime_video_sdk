import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:prime_video_library/model/models.dart';
import 'package:prime_video_library/util/constance.dart';

import '../model/consultation_response.dart';
import '../model/login_response.dart';
import '../ui/call_screen.dart';
import '../util/progress_dialog.dart';


class Network {
  Future<LoginResponse> login(DataModel dataModel) async {
    DataModel dataModel1 = await DataModel.create();
    dataModel.os = dataModel1.os;
    dataModel.ipAddress = dataModel1.ipAddress;
    dataModel.userAgent = dataModel1.userAgent;
    RequestDataModel requestModel = RequestDataModel(
        token:
        'fcfb70e15b304a88af137f8a0906e65c0bc7f1d662e6aed146f34c0e975d6756',
        C2MDVerificationToken: '',
        requestType: '3',
        dataModel: dataModel);
    final url = '${Constants.endPoint}passcodelogin';
    print(requestModel.toJson());
    final response = await http.post(Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(requestModel.toJson()));
    if (response.statusCode == 200) {
      return LoginResponse.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create user');
    }
  }

  Future<String> joinConsultation(
      BuildContext context, String appointmentID) async {

    ProgressDialog.show(context);
    DataModel dataModel = await DataModel.create();
    ConsultationRequestModel consultationRequestModel =
    ConsultationRequestModel(
        consultationId: appointmentID,
        userType: "Patient",
        browserTimeZone: "GMT%2D05:30",
        currency: "INR",
        accessCountry: "IN",
        todayRate: "");
    consultationRequestModel.os = dataModel.os;
    consultationRequestModel.ipAddress = dataModel.ipAddress;
    consultationRequestModel.userAgent = dataModel.userAgent;
    RequestDataModel requestModel = RequestDataModel(
        token:
        'fcfb70e15b304a88af137f8a0906e65c0bc7f1d662e6aed146f34c0e975d6756',
        C2MDVerificationToken: '',
        requestType: '400',
        dataModel: consultationRequestModel);
    final url = '${Constants.endPoint}consultation';
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
          !(consultationResponse.data?.tokenId?.isEmpty ?? false) && !(consultationResponse.data?.patientName?.isEmpty ?? false)) {
        final result = await Navigator.pushNamed(context, "Call",
            arguments: CallArguments(consultationResponse.data!.sessionId!,
                consultationResponse.data!.tokenId!, '', '', '40', '', true));
        if (result != null) {
          return "Consultation completed";
        } else {
          return "Cancelled or No Data Returned";
        }
      } else {
        return "Consultation is not available with the appointment ID";
      }
    } else {
      return "Unable to connect to API. Please try again after sometime";
    }
  }
}