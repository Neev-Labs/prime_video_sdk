import 'package:prime_video_library/util/common.dart';

class DataModel {
  String ipAddress;
  String userAgent;
  String os;

  DataModel({required this.ipAddress, required this.userAgent, required this.os});

  static Future<DataModel> create() async {
    String ipAddress = await Common().getIPAddress();
    String userAgent = await Common().getPhoneModel();
    String os = await Common().getOSVersion();
    return DataModel(ipAddress: ipAddress, userAgent: userAgent, os: os);
  }

  Map<String, dynamic> toJson() {
    return {
      'Ipaddress': ipAddress,
      'useragent': userAgent,
      'Os': os,
    };
  }

  factory DataModel.fromJson(Map<String, dynamic> json) {
    return DataModel(
      ipAddress: json['Ipaddress'] ?? '',
      userAgent: json['useragent'] ?? '',
      os: json['Os'] ?? '',
    );
  }
}

class LoginRequestModel extends DataModel {
  String otp;
  String userType;
  String browserTimeZone;

  LoginRequestModel({
    required this.otp,
    required this.userType,
    required this.browserTimeZone,
  }) : super(ipAddress: '', userAgent: '', os: '');

  factory LoginRequestModel.fromJson(Map<String, dynamic> json) {
    return LoginRequestModel(
      otp: json['Otp'] ?? '',
      userType: json['userType'] ?? '',
      browserTimeZone: json['browserTimeZone'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'Otp': otp,
      'userType': userType,
      'browserTimeZone': browserTimeZone,
    };
  }
}

class RequestModel {
  String token;
  String C2MDVerificationToken;
  String requestType;

  RequestModel({
    required this.token,
    required this.C2MDVerificationToken,
    required this.requestType,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      token: json['token'] ?? '',
      C2MDVerificationToken: json['C2MDVerificationToken'] ?? '',
      requestType: json['requestType'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'C2MDVerificationToken': C2MDVerificationToken,
      'requestType': requestType,
    };
  }
}

class RequestDataModel extends RequestModel {
  DataModel dataModel;

  RequestDataModel({
    required this.dataModel,
    required super.token,
    required super.C2MDVerificationToken,
    required super.requestType,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'data': dataModel.toJson(),
    };
  }

  factory RequestDataModel.fromJson(Map<String, dynamic> json) {
    return RequestDataModel(
      dataModel: DataModel.fromJson(json['data']),
      token: json['token'] ?? '',
      C2MDVerificationToken: json['C2MDVerificationToken'] ?? '',
      requestType: json['requestType'] ?? '',
    );
  }
}
