class LoginResponse {
  Data? data;
  String? errorType;
  int? request;
  int? status;

  LoginResponse({this.data, this.errorType, this.request, this.status});

  LoginResponse.fromJson(Map<String, dynamic> json) {
    data = json['data'] != null ? new Data.fromJson(json['data']) : null;
    errorType = json['errorType'];
    request = json['request'];
    status = json['status'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    data['errorType'] = this.errorType;
    data['request'] = this.request;
    data['status'] = this.status;
    return data;
  }
}

class Data {
  String? fullname;
  String? relationship;
  String? oTPstatus;
  ConsultationDetails? consultationDetails;

  Data(
      {this.fullname,
      this.relationship,
      this.oTPstatus,
      this.consultationDetails});

  Data.fromJson(Map<String, dynamic> json) {
    fullname = json['fullname'];
    relationship = json['relationship'];
    oTPstatus = json['OTPstatus'];
    consultationDetails = json['consultationDetails'] != null
        ? new ConsultationDetails.fromJson(json['consultationDetails'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['fullname'] = this.fullname;
    data['relationship'] = this.relationship;
    data['OTPstatus'] = this.oTPstatus;
    if (this.consultationDetails != null) {
      data['consultationDetails'] = this.consultationDetails!.toJson();
    }
    return data;
  }
}

class ConsultationDetails {
  String? appointmentId;
  String? mode;
  String? reasonforvisit;
  String? ispartner;
  String? sessionId;
  String? patientToken;
  int? apiKey;
  String? patientName;
  String? patientImage;
  String? doctorName;
  String? doctorImage;
  String? lastconsultOn;
  String? speciality;
  String? displayeducation;
  String? message;

  ConsultationDetails({this.appointmentId, this.mode, this.reasonforvisit, this.ispartner, this.sessionId, this.patientToken, this.apiKey, this.patientName, this.patientImage, this.doctorName, this.doctorImage, this.lastconsultOn,this.speciality, this.displayeducation, this.message});

  ConsultationDetails.fromJson(Map<String, dynamic> json) {
    appointmentId = json['appointmentId'];
    mode = json['mode'];
    reasonforvisit = json['reasonforvisit'];
    ispartner = json['Ispartner'];
    sessionId = json['sessionId'];
    patientToken = json['patientToken'];
    apiKey = json['apiKey'];
    patientName = json['PatientName'];
    patientImage = json['patientImage'];
    doctorName = json['doctorName'];
    doctorImage = json['doctorImage'];
    lastconsultOn = json['lastconsultOn'];
    speciality = json['speciality'];
    displayeducation = json['displayeducation'];
    message = json['message'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['appointmentId'] = this.appointmentId;
    data['mode'] = this.mode;
    data['reasonforvisit'] = this.reasonforvisit;
    data['Ispartner'] = this.ispartner;
    data['sessionId'] = this.sessionId;
    data['patientToken'] = this.patientToken;
    data['apiKey'] = this.apiKey;
    data['PatientName'] = this.patientName;
    data['patientImage'] = this.patientImage;
    data['doctorName'] = this.doctorName;
    data['doctorImage'] = this.doctorImage;
    data['lastconsultOn'] = this.lastconsultOn;
    data['speciality'] = this.speciality;
    data['displayeducation'] = this.displayeducation;
    data['message'] = this.message;
    return data;
  }
}

