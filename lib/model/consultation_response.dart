class ConsultationResponse {
  ConsultationResponseData? data;
  String? errorType;
  int? request;
  int? status;

  ConsultationResponse({this.data, this.errorType, this.request, this.status});

  ConsultationResponse.fromJson(Map<String, dynamic> json) {
    data = json['data'] != null ? new ConsultationResponseData.fromJson(json['data']) : null;
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

class ConsultationResponseData {
  int? apiKey;
  String? sessionId;
  String? modeOfConsultation;
  String? reasonforvisit;
  String? notesToDoctor;
  String? appointmentDate;
  String? appointmentTime;
  int? appointmentTimeinMilliSec;
  int? appointmentEndTimeinMilliSec;
  int? gmtTimeInMilliSec;
  int? durationInMilliSec;
  String? appointmentFor;
  String? currency;
  String? todayRate;
  String? patientName;
  String? doctorName;
  String? tokenId;
  String? cliniclogo;
  DoctorDetails? doctorDetails;
  String? doctorStatus;
  String? patientStatus;
  String? doctorScreenstatus;

  ConsultationResponseData(
      {this.apiKey,
        this.sessionId,
        this.modeOfConsultation,
        this.reasonforvisit,
        this.notesToDoctor,
        this.appointmentDate,
        this.appointmentTime,
        this.appointmentTimeinMilliSec,
        this.appointmentEndTimeinMilliSec,
        this.gmtTimeInMilliSec,
        this.durationInMilliSec,
        this.appointmentFor,
        this.currency,
        this.todayRate,
        this.patientName,
        this.doctorName,
        this.tokenId,
        this.cliniclogo,
        this.doctorDetails,
        this.doctorStatus,
        this.patientStatus,
        this.doctorScreenstatus,
      });

  ConsultationResponseData.fromJson(Map<String, dynamic> json) {
    apiKey = json['apiKey'];
    sessionId = json['sessionId'];
    modeOfConsultation = json['modeOfConsultation'];
    reasonforvisit = json['reasonforvisit'];
    notesToDoctor = json['notesToDoctor'];
    appointmentDate = json['appointmentDate'];
    appointmentTime = json['appointmentTime'];
    appointmentTimeinMilliSec = json['appointmentTimeinMilliSec'];
    appointmentEndTimeinMilliSec = json['appointmentEndTimeinMilliSec'];
    gmtTimeInMilliSec = json['gmtTimeInMilliSec'];
    durationInMilliSec = json['durationInMilliSec'];
    appointmentFor = json['appointmentFor'];
    currency = json['currency'];
    todayRate = json['todayRate'];
    patientName = json['patientName'];
    doctorName = json['doctorName'];
    tokenId = json['tokenId'];
    cliniclogo = json['cliniclogo'];
    doctorDetails = json['doctorDetails'] != null
        ? new DoctorDetails.fromJson(json['doctorDetails'])
        : null;
    doctorStatus = json['doctorStatus'];
    patientStatus = json['patientStatus'];
    doctorScreenstatus = json['doctorScreenstatus'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['apiKey'] = this.apiKey;
    data['sessionId'] = this.sessionId;
    data['modeOfConsultation'] = this.modeOfConsultation;
    data['reasonforvisit'] = this.reasonforvisit;
    data['notesToDoctor'] = this.notesToDoctor;
    data['appointmentDate'] = this.appointmentDate;
    data['appointmentTime'] = this.appointmentTime;
    data['appointmentTimeinMilliSec'] = this.appointmentTimeinMilliSec;
    data['appointmentEndTimeinMilliSec'] = this.appointmentEndTimeinMilliSec;
    data['gmtTimeInMilliSec'] = this.gmtTimeInMilliSec;
    data['durationInMilliSec'] = this.durationInMilliSec;
    data['appointmentFor'] = this.appointmentFor;
    data['currency'] = this.currency;
    data['todayRate'] = this.todayRate;
    data['patientName'] = this.patientName;
    data['doctorName'] = this.doctorName;
    data['tokenId'] = this.tokenId;
    data['cliniclogo'] = this.cliniclogo;
    if (this.doctorDetails != null) {
      data['doctorDetails'] = this.doctorDetails!.toJson();
    }
    data['doctorStatus'] = this.doctorStatus;
    data['patientStatus'] = this.patientStatus;
    data['doctorScreenstatus'] = this.doctorScreenstatus;
    return data;
  }
}

class DoctorDetails {
  String? basicFees;
  String? bookingType;
  bool? c2mdSlotAvailable;
  String? c2mdfees;
  String? coverImage;
  String? doctorFirstname;
  String? doctorId;
  String? doctorImage;
  String? doctorName;
  String? doctorURL;
  String? doctorfees;
  String? emailId;
  String? fees;
  String? gender;
  String? gstamount;
  String? gstfees;
  bool? inclinicSlotAvailable;
  String? language;
  String? location;
  String? mobileNumber;
  String? qualification;
  int? rating;
  String? referredBy;
  bool? requestSlotAvailable;
  int? reviews;
  String? sharePercentage;
  String? specialityList;
  String? specialization;
  String? status;
  String? urlSpeciality;

  DoctorDetails(
      {this.basicFees,
        this.bookingType,
        this.c2mdSlotAvailable,
        this.c2mdfees,
        this.coverImage,
        this.doctorFirstname,
        this.doctorId,
        this.doctorImage,
        this.doctorName,
        this.doctorURL,
        this.doctorfees,
        this.emailId,
        this.fees,
        this.gender,
        this.gstamount,
        this.gstfees,
        this.inclinicSlotAvailable,
        this.language,
        this.location,
        this.mobileNumber,
        this.qualification,
        this.rating,
        this.referredBy,
        this.requestSlotAvailable,
        this.reviews,
        this.sharePercentage,
        this.specialityList,
        this.specialization,
        this.status,
        this.urlSpeciality});

  DoctorDetails.fromJson(Map<String, dynamic> json) {
    basicFees = json['basicFees'];
    bookingType = json['bookingType'];
    c2mdSlotAvailable = json['c2mdSlotAvailable'];
    c2mdfees = json['c2mdfees'];
    coverImage = json['coverImage'];
    doctorFirstname = json['doctorFirstname'];
    doctorId = json['doctorId'];
    doctorImage = json['doctorImage'];
    doctorName = json['doctorName'];
    doctorURL = json['doctorURL'];
    doctorfees = json['doctorfees'];
    emailId = json['emailId'];
    fees = json['fees'];
    gender = json['gender'];
    gstamount = json['gstamount'];
    gstfees = json['gstfees'];
    inclinicSlotAvailable = json['inclinicSlotAvailable'];
    language = json['language'];
    location = json['location'];
    mobileNumber = json['mobileNumber'];
    qualification = json['qualification'];
    rating = json['rating'];
    referredBy = json['referredBy'];
    requestSlotAvailable = json['requestSlotAvailable'];
    reviews = json['reviews'];
    sharePercentage = json['sharePercentage'];
    specialityList = json['specialityList'];
    specialization = json['specialization'];
    status = json['status'];
    urlSpeciality = json['urlSpeciality'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['basicFees'] = this.basicFees;
    data['bookingType'] = this.bookingType;
    data['c2mdSlotAvailable'] = this.c2mdSlotAvailable;
    data['c2mdfees'] = this.c2mdfees;
    data['coverImage'] = this.coverImage;
    data['doctorFirstname'] = this.doctorFirstname;
    data['doctorId'] = this.doctorId;
    data['doctorImage'] = this.doctorImage;
    data['doctorName'] = this.doctorName;
    data['doctorURL'] = this.doctorURL;
    data['doctorfees'] = this.doctorfees;
    data['emailId'] = this.emailId;
    data['fees'] = this.fees;
    data['gender'] = this.gender;
    data['gstamount'] = this.gstamount;
    data['gstfees'] = this.gstfees;
    data['inclinicSlotAvailable'] = this.inclinicSlotAvailable;
    data['language'] = this.language;
    data['location'] = this.location;
    data['mobileNumber'] = this.mobileNumber;
    data['qualification'] = this.qualification;
    data['rating'] = this.rating;
    data['referredBy'] = this.referredBy;
    data['requestSlotAvailable'] = this.requestSlotAvailable;
    data['reviews'] = this.reviews;
    data['sharePercentage'] = this.sharePercentage;
    data['specialityList'] = this.specialityList;
    data['specialization'] = this.specialization;
    data['status'] = this.status;
    data['urlSpeciality'] = this.urlSpeciality;
    return data;
  }
}