import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:prime_video_library/model/models.dart';
import 'package:prime_video_library/util/constance.dart';

import '../model/login_response.dart';

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
}
