import 'dart:convert';

class ConsultationModel {
  String? appointmentId;
  String? doctorScreenStatus;
  String? doctorStatus;
  String? doctorImage;
  String? mode;
  String? apiKey;
  String? sessionId;
  String? patientToken;
  String? doctorName;
  String? speciality;
  String? displayEducation;
  String? isPartner;
  String status = ""; // Local status
  String? videoCallSDK;
  String? typeOfConsultation;
  String? appointmentDateTime;
  

  ConsultationModel({
    this.appointmentId,
    this.doctorScreenStatus,
    this.doctorStatus,
    this.doctorImage,
    this.mode,
    this.apiKey,
    this.sessionId,
    this.patientToken,
    this.doctorName,
    this.speciality,
    this.displayEducation,
    this.isPartner,
    this.status = "",
    this.videoCallSDK,
    this.typeOfConsultation,
    this.appointmentDateTime,
  });
  
  // Named constructor for simplified initialization
  ConsultationModel.fromSessionIdAndToken({
     this.sessionId, 
     this.patientToken,
     this.doctorName,
     this.doctorImage,
     this.status = ""
  });

  factory ConsultationModel.fromJson(Map<String, dynamic> json) {
    return ConsultationModel(
      appointmentId: json['appointmentId'],
      doctorScreenStatus: json['doctorScreenstatus'],
      doctorStatus: json['doctorstatus'],
      doctorImage: json['doctorImage'],
      mode: json['mode'],
      apiKey: json['apiKey'],
      sessionId: json['sessionId'],
      patientToken: json['patientToken'],
      doctorName: json['doctorName'],
      speciality: json['speciality'],
      displayEducation: json['displayeducation'],
      isPartner: json['Ispartner'],
      videoCallSDK: json['VideocallApp'],
      typeOfConsultation: json['typeofconsultation'],
      appointmentDateTime: json['appointmentDatetimenew'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appointmentId': appointmentId,
      'doctorScreenstatus': doctorScreenStatus,
      'doctorstatus': doctorStatus,
      'doctorImage': doctorImage,
      'mode': mode,
      'apiKey': apiKey,
      'sessionId': sessionId,
      'patientToken': patientToken,
      'doctorName': doctorName,
      'speciality': speciality,
      'displayeducation': displayEducation,
      'Ispartner': isPartner,
      'VideocallApp': videoCallSDK,
      'typeofconsultation': typeOfConsultation,
      'appointmentDatetimenew': appointmentDateTime,
    };
  }
}