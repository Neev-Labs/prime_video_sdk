import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:integrated_project/ui/waiting_room_ads.dart';
import 'dart:convert';
import 'dart:async';
import '../network/network.dart';
import '../model/consultation_check_response.dart';

class WaitingRoomScreen extends StatefulWidget {
  final String appointmentId;
  final bool isProduction;
  final String? reasonForVisit;
  final String? doctorName;
  final String? appointmentDate;
  final String? appointmentTime;

  const WaitingRoomScreen({
    super.key,
    required this.appointmentId,
    required this.isProduction,
    this.reasonForVisit,
    this.doctorName,
    this.appointmentDate,
    this.appointmentTime,
  });

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  final String jsonString = '''
  {
      "request":1,
      "errorType":"Success",
      "data":{
          "type":"An image and description",
          "ads":[
              {
                  "videoLink":null,
                  "image":"https://www.caritashospital.org/static/img/video-consultation-banner.jpg",
                  "description":"<h5 style=\\"margin:0 0 6px 0;\\">Caritas Video Consultation</h5><p>Your health journey matters. With our Video Consultation service, meet your doctor from anywhere.</p><ul><li>Fast and secure</li><li>Trusted by thousands</li><li>24/7 availability</li></ul>",
                  "callToActionText":"Learn More",
                  "clickthroughUrl":"https://www.caritashospital.org/video-consultation/"
              },
              {
                  "videoLink":null,
                  "image":"https://www.caritashospital.org/static/media/images/drone-banner.jpeg",
                  "description":"<h5 style=\\"margin:0 0 6px 0;\\">Drone Delivery Unit</h5><p><em>South Kerala’s first</em> drone-based medical delivery system.<br/>Delivering medicines and samples in <strong>record time</strong>.</p><p style=\\"color:#0060d6; font-weight:600;\\">Powered by Caritas Hospital</p>",
                  "callToActionText":"Click Here",
                  "clickthroughUrl":"https://www.caritashospital.org/caritas-social-responsibility/caritas-hospital-introduced-south-keralas-first-drone-based-medical-deliveries-unit"
              },
              {
                  "videoLink":null,
                  "image":"https://caritascollege.edu.in/wp-content/uploads/2021/08/Admission-B.Pharm-2021.jpeg",
                  "description":"<h5 style=\\"margin:0 0 6px 0;\\">B.Pharm Admission 2025</h5><p>The online application is now <strong>open</strong>.</p><p>Last date: <span style=\\"color:red;\\">06/09/2025</span></p><ol><li>Register online</li><li>Upload your documents</li><li>Submit application</li></ol>",
                  "callToActionText":"Apply Now",
                  "clickthroughUrl":"https://caritascollege.edu.in/b-pharm-admission-2021/"
              }
          ]
      },
      "status":200
  }
  ''';

  late Timer _timer;
  Timer? _pollingTimer;
  int _secondsRemaining = 300; // 5:00 in seconds
  String? _patientId;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _startPolling();
    _fetchPatientDetails();
  }

  Future<void> _fetchPatientDetails() async {
    final response = await Network().consultationCheck(
      widget.appointmentId,
      widget.isProduction,
    );
    if (response != null && response.data?.patientId != null) {
      if (mounted) {
        setState(() {
          _patientId = response.data!.patientId;
        });
      }
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      await Network().joinConsultation(
        context,
        widget.appointmentId,
        widget.isProduction,
        isFromWaitingRoom: true,
      );
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer.cancel();
        _showTimeoutDialog();
      }
    });
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning, color: Colors.red[400], size: 28),
                    const SizedBox(width: 8),
                    const Text(
                      "Estimated Wait Time",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                 const Text(
                    "Reached",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  "Thanks for your patience. The doctor may join soon — would you like to continue waiting or leave the session?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                           Navigator.of(context).pop(); // Close dialog
                           Navigator.of(context).pop(); // Go back to previous page
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF673AB7)),
                          foregroundColor: const Color(0xFF673AB7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text("Leave"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          setState(() {
                            _secondsRemaining = 300; // Reset to 5 mins
                          });
                          _startTimer(); // Restart timer
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF673AB7),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text("Stay"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    final List<dynamic> ads = jsonData['data']['ads'];
    final primaryColor = const Color(0xFF673AB7); 

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea( // Use SafeArea since AppBar is gone
         child: SingleChildScrollView(
         child: Padding(
           padding: const EdgeInsets.all(12.0),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
              // Main Status Box
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Waiting Room -",
                                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text("Appointment ID: ${widget.appointmentId}",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              if (_patientId != null)
                                Text("Patient ID: $_patientId",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("Estimated wait time 5",
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text("min: $_formattedTime", 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Body Section
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // Left aligned
                        children: [
                          // Video Preview
                          Center( // Image keeps centered usually, or should it be left? "all text... left aligned". Images usually center. keeping center for now unless requested.
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 120,
                                height: 120,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Doctor Info
                          Text(
                            "${widget.reasonForVisit ?? "First time consultation"} with ${widget.doctorName ?? "Dr. Vps Doctor"}",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.start,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Scheduled: ${widget.appointmentDate ?? "12-Jan-2026"}, ${widget.appointmentTime ?? "10:05 AM"}",
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.start,
                          ),
                          const SizedBox(height: 24),

                          // Waiting Status
                          Row(
                            children: [ // Left aligned row
                              const Text(
                                "Waiting for the Doctor to start the meeting",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                               const SizedBox(width: 8),
                              SizedBox(
                                height: 50,
                                width: 50,
                                child: Lottie.asset('assets/animations/loader.json'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Test Speaker Link (Left aligned)
                          InkWell(
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    "Test Speaker and Mic",
                                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Disclaimer
                          Center(
                            child: const Text(
                              "Clicking the advertisement opens it in a new tab — session stays active.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 16),

                           // Ads Component (Inside the padding)
                           WaitingRoomAds(adsData: ads),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
             ],
           ),
         ),
      ),
    ));
  }
}
