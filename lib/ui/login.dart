import 'package:flutter/material.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart';
import 'package:prime_video_library/model/login_response.dart';
import 'package:prime_video_library/model/models.dart';
import 'package:prime_video_library/network/network.dart';
import 'package:prime_video_library/util/common.dart';

import 'call_screen.dart';

class JoinArguments {
  final bool isJoin;
  final String sessionName;
  final String sessionPwd;
  final String displayName;
  final String sessionTimeout;
  final String roleType;

  JoinArguments(this.isJoin, this.sessionName, this.sessionPwd,
      this.displayName, this.sessionTimeout, this.roleType);
}

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final myController = TextEditingController();

  @override
  void dispose() {
    myController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var zoom = ZoomVideoSdk();
    InitConfig initConfig = InitConfig(
      domain: "zoom.us",
      enableLog: true,
    );
    zoom.initSdk(initConfig);
    void createLoginRequest(String PIN) async {
      LoginRequestModel loginRequestModel = LoginRequestModel(
          otp: PIN, userType: '', browserTimeZone: Common().getGMTOffset());
      LoginResponse loginResponse = await Network().login(loginRequestModel);
      if (loginResponse.data != null &&
          loginResponse.data?.consultationDetails != null) {
        print('in response');
        ConsultationDetails? consultationDetails =
            loginResponse.data?.consultationDetails;
        Navigator.pushNamed(context, "Call",
            arguments: CallArguments(consultationDetails!.sessionId!,
                consultationDetails.patientToken!, '', '', '40', '', true));
      }
    }

    return PopScope(
      canPop: false, // Prevent default back navigation
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // If system already handled back press, do nothing

        bool exitApp = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Exit App"),
            content: Text("Do you really want to exit?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false), // Stay in app
                child: Text("No"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true), // Exit app
                child: Text("Yes"),
              ),
            ],
          ),
        ) ?? false;

        if (exitApp) {
          Navigator.of(context).pop(); // Manually handle back action
        }
      },
      child: Scaffold(
          body: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32.0, vertical: 0.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 16.0,
                      children: [
                        TextFormField(
                          controller: myController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Enter PIN',
                              counterText: ""),
                          maxLength: 5,
                          validator: (value) {
                            if (value == null || value.length < 5) {
                              return 'Enter a valid PIN';
                            }
                            return null;
                          },
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                          ),
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              createLoginRequest(myController.text);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Processing Data')),
                              );
                            }
                          },
                          child: const Text(
                            'Join Now',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  )))),
    );
  }
}
