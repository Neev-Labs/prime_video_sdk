class ConsultationCheckResponse {
  ConsultationCheckData? data;
  String? errorType;
  int? request;
  int? status;

  ConsultationCheckResponse({this.data, this.errorType, this.request, this.status});

  ConsultationCheckResponse.fromJson(Map<String, dynamic> json) {
    data = json['data'] != null ? ConsultationCheckData.fromJson(json['data']) : null;
    errorType = json['errorType'];
    request = json['request'];
    status = json['status'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    data['errorType'] = errorType;
    data['request'] = request;
    data['status'] = status;
    return data;
  }
}

class ConsultationCheckData {
  String? appointmentId;
  String? duration;
  String? appointmentType;
  String? patientId;
  String? doctorId;
  String? patientFirstName;
  String? patientLastName;
  String? displayDate;
  String? displayTime;
  String? appointmentStatus;
  bool? isValid;
  String? doctorName;
  String? customerId;

  ConsultationCheckData({
    this.appointmentId,
    this.duration,
    this.appointmentType,
    this.patientId,
    this.doctorId,
    this.patientFirstName,
    this.patientLastName,
    this.displayDate,
    this.displayTime,
    this.appointmentStatus,
    this.isValid,
    this.doctorName,
    this.customerId,
  });

  ConsultationCheckData.fromJson(Map<String, dynamic> json) {
    appointmentId = json['AppointmentId'];
    duration = json['duration'];
    appointmentType = json['AppointmentType'];
    patientId = json['patientId'];
    doctorId = json['doctorId'];
    patientFirstName = json['patientFirstName'];
    patientLastName = json['patientLastName'];
    displayDate = json['displayDate'];
    displayTime = json['displayTime'];
    appointmentStatus = json['appointmentStatus'];
    isValid = json['Isvalid'];
    doctorName = json['doctorName'];
    customerId = json['customerId'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['AppointmentId'] = appointmentId;
    data['duration'] = duration;
    data['AppointmentType'] = appointmentType;
    data['patientId'] = patientId;
    data['doctorId'] = doctorId;
    data['patientFirstName'] = patientFirstName;
    data['patientLastName'] = patientLastName;
    data['displayDate'] = displayDate;
    data['displayTime'] = displayTime;
    data['appointmentStatus'] = appointmentStatus;
    data['Isvalid'] = isValid;
    data['doctorName'] = doctorName;
    data['customerId'] = customerId;
    return data;
  }
}
