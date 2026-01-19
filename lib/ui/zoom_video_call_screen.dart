import 'dart:async';
import 'dart:convert';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_camera_device.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_event_listener.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_share_action.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_user.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prime_video_library/model/consultation_model.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../components/video_view.dart';

class ZoomVideoCallScreen extends StatefulWidget {
  final ConsultationModel consultationModel;

  const ZoomVideoCallScreen({Key? key, required this.consultationModel})
      : super(key: key);

  @override
  State<ZoomVideoCallScreen> createState() => _ZoomVideoCallScreenState();
}

class _ZoomVideoCallScreenState extends State<ZoomVideoCallScreen>
    with WidgetsBindingObserver {
  late ZoomVideoSdk _zoomVideoSdk;
  bool _isJoined = false;
  bool _isVideoOn = true;
  bool _isAudioOn = true;
  bool _isDoctorVideoOn = true;
  bool _isDoctorAudioMuted = false;
  bool _showControls = true;
  bool _doctorScreenshareFlag = false;
  bool _consultationEndFlag = false;
  bool _isRecordingStarted = false;
  int _videoViewKey = 0;
  int _selfViewRotation = 0;

  ZoomVideoSdkUser? _doctorUser;
  ZoomVideoSdkUser? _mySelf;

  Timer? _controlsTimer;
  Timer? _doctorLeftTimer;

  ZoomVideoSdkEventListener _eventListener = ZoomVideoSdkEventListener();
  final List<dynamic> _listeners = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _zoomVideoSdk = ZoomVideoSdk();
    WakelockPlus.enable();
    _initZoom();

    // Auto-hide controls after 5 seconds
    _resetControlsTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (var listener in _listeners) {
      listener.cancel();
    }
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print("App Resumed: Refreshing video state");
      print("Lifecycle State: $state, Mounted: $mounted, Flag: $_doctorScreenshareFlag");
      // Force refresh of video views
      if (mounted) {
        // Combined state update to ensure UI reflects changes atomically
        setState(() {
          _videoViewKey++;
          if (_doctorScreenshareFlag) {
            print("SetState: Setting rotation to 3");
            _selfViewRotation = 1;
          } else {
             _selfViewRotation = 0;
          }
        });

        // If video was on, ensure it's restarted or preview is active
        if (_isVideoOn) {
           // Toggle video to force camera re-acquisition
           _zoomVideoSdk.videoHelper.stopVideo();
           Future.delayed(Duration(milliseconds: 500), () {
             _zoomVideoSdk.videoHelper.startVideo();
           });
        }
        
        // Re-enforce orientation if screen sharing
        if (_doctorScreenshareFlag) {
          AutoOrientation.landscapeAutoMode();
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight
          ]);
        }
      }
    }
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) _resetControlsTimer();
  }

  Future<void> _initZoom() async {
    try {
      await _zoomVideoSdk.initSdk(
        InitConfig(
          domain: 'zoom.us',
          enableLog: true,
        ),
      );
    } catch (e) {
      print("Zoom SDK Init Error (safe to ignore if already initialized): $e");
    }

    _listeners
        .add(_eventListener.addListener(EventType.onSessionJoin, (data) async {
      print("Session Joined");
      if (mounted) {
        setState(() {
          _isJoined = true;
        });
        _startPreview();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    "As required by Dubai Health telemedicine guidelines, this consultation’s audio will be recorded for clinical and quality purposes. By staying on this call, you agree to the recording.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("OK",
                          style: TextStyle(color: Colors.white)),
                    ),
                  )
                ],
              ),
            );
          },
        );
        await _checkRemoteUsers();
        if (mounted) {
          setState(() {
            _isRecordingStarted = true;
          });
        }
      }
    }));

    _listeners.add(_eventListener.addListener(EventType.onError, (data) {
      print("[ZoomVideoCallScreen] SDK Error: $data");
      // Handle 'Session Already In Progress' as a successful join (re-entry)
      if (data
          .toString()
          .contains("ZoomVideoSDKError_Session_Already_In_Progress")) {
        print("Recovering from already in progress session...");
        if (mounted) {
          setState(() {
            _isJoined = true;
            _isRecordingStarted = true; // Show recording indicator
          });
          _startPreview();
          // Trigger the logic to check for remote users as if we just joined
          _checkRemoteUsers();
        }
      }
    }));

    _listeners.add(_eventListener.addListener(EventType.onSessionLeave, (data) {
      print("Session Left");
      if (!_consultationEndFlag) {
        // Doctor ended the session
        _endCallProperly("PSDK_1");
      } else {
        // User left manually or cleanup
        _endCallProperly();
      }
    }));

    _listeners.add(_eventListener.addListener(EventType.onUserJoin, (data) {
      data = data as Map;
      var userListJson = jsonDecode(data['remoteUsers']) as List;
      List<ZoomVideoSdkUser> userList = userListJson
          .map((userJson) => ZoomVideoSdkUser.fromJson(userJson))
          .toList();

      for (var user in userList) {
        if (user.userName.contains("Doctor")) {
          if (mounted) {
            setState(() {
              _doctorUser = user;
              _consultationEndFlag = false;
              widget.consultationModel.status = ""; // Connected
            });
          }
        }
      }
    }));

    _listeners.add(_eventListener.addListener(EventType.onUserLeave, (data) {
      // Doctor Stepped Away Logic
      _doctorLeftTimer?.cancel();
      _doctorLeftTimer = Timer(const Duration(seconds: 1), () async {
        if (_consultationEndFlag) return;

        bool doctorGone = true;
        // Re-check remote users list
        final remoteUsers = await _zoomVideoSdk.session.getRemoteUsers();
        if (remoteUsers != null) {
          for (var user in remoteUsers) {
            if (user.userName.contains("Doctor")) {
              doctorGone = false;
              break;
            }
          }
        }

        if (doctorGone && !_consultationEndFlag && mounted) {
          setState(() {
            _doctorUser = null;
            _isDoctorVideoOn = false;
            _doctorScreenshareFlag = false;
            widget.consultationModel.status =
                "The doctor has stepped away/left this session";
          });

          // Restore orientation if needed
          SystemChrome.setPreferredOrientations([]);
          AutoOrientation.portraitAutoMode();

          _showSteppedAwayAlert();
        }
      });
    }));

    _listeners.add(
        _eventListener.addListener(EventType.onUserVideoStatusChanged, (data) {
      data = data as Map;
      var userListJson = jsonDecode(data['changedUsers']) as List;
      List<ZoomVideoSdkUser> userList = userListJson
          .map((userJson) => ZoomVideoSdkUser.fromJson(userJson))
          .toList();

      for (var user in userList) {
        if (user.userName.contains("Doctor")) {
          // Check status
          user.videoStatus?.isOn().then((isOn) {
            if (mounted) {
              setState(() {
                _isDoctorVideoOn = isOn;
                if (!isOn) {
                  widget.consultationModel.status = "Doctor disabled camera";
                } else {
                  widget.consultationModel.status = "";
                }
              });
            }
          });
        }
      }
    }));

    _listeners.add(
        _eventListener.addListener(EventType.onCloudRecordingStatus, (data) {
      data = data as Map;
      print("onCloudRecordingStatus: status: ${data['status']}");
      if (data['status'] == RecordingStatus.Start) {
        // Show recording dialog if needed, similar to CallScreen
        // Since user already agreed to disclaimer on join, we might just toast or ignore
        // But let's add the listener for completeness as requested.
        _zoomVideoSdk.acceptRecordingConsent();
      }
    }));

    _listeners.add(
        _eventListener.addListener(EventType.onUserShareStatusChanged, (data) {
      data = data as Map;
      ZoomVideoSdkUser user =
          ZoomVideoSdkUser.fromJson(jsonDecode(data['user'].toString()));
      ZoomVideoSdkShareAction shareAction =
          ZoomVideoSdkShareAction.fromJson(jsonDecode(data['shareAction']));

      if (user.userName.contains("Doctor")) {
        if (shareAction.shareStatus == ShareStatus.Start) {
          if (mounted) {
            setState(() {
              _selfViewRotation = 3;
              _doctorScreenshareFlag = true;
            });
          }
          // Force Landscape
          AutoOrientation.landscapeAutoMode();
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight
          ]);
        } else {
          // Share Stop
          if (mounted) {
            setState(() {
              _doctorScreenshareFlag = false;
              _selfViewRotation = 0; // Reset rotation
              // Force Video On logic
              if (!_isVideoOn) {
                _isVideoOn = true;
                _zoomVideoSdk.videoHelper.startVideo();
              }
            });
            // Force Portrait
            SystemChrome.setPreferredOrientations([]);
            AutoOrientation.portraitAutoMode();
          }

        }
      }
    }));

    // Request Permissions
    await [Permission.camera, Permission.microphone].request();

    _joinSession();
  }

  Future<void> _checkRemoteUsers() async {
    // Proactively check for existing remote users (Doctor might already be there)
    List<ZoomVideoSdkUser>? remoteUsers =
        await _zoomVideoSdk.session.getRemoteUsers();
    print("Check Remote Users: ${remoteUsers?.length}");
    if (remoteUsers != null) {
      for (var user in remoteUsers) {
        print("Remote User: ${user.userName}");
        if (user.userName.contains("Doctor")) {
          setState(() {
            _doctorUser = user;
            _consultationEndFlag = false;
            widget.consultationModel.status = "";

            // Check if doctor video is on/off
            user.videoStatus?.isOn().then((isOn) {
              if (mounted) {
                setState(() {
                  _isDoctorVideoOn = isOn;
                  if (!isOn)
                    widget.consultationModel.status = "Doctor disabled camera";
                });
              }
            });
          });
        }
      }
    }
  }

  Future<void> _joinSession() async {
    Map<String, bool> audioOptions = {
      "connect": true,
      "mute": false,
      "autoAdjustSpeakerVolume": false
    };
    Map<String, bool> videoOptions = {
      "localVideoOn": true,
    };

    JoinSessionConfig joinSession = JoinSessionConfig(
      sessionName: widget.consultationModel.sessionId!,
      token: widget.consultationModel.patientToken!,
      userName: "Patient",
      // or Guest based on type
      sessionPassword: "",
      audioOptions: audioOptions,
      videoOptions: videoOptions,
      sessionIdleTimeoutMins: 40,
    );

    await _zoomVideoSdk.joinSession(joinSession);
  }

  void _startPreview() async {
    try {
      // Ensure video is started
      await _zoomVideoSdk.videoHelper.startVideo();
      // Add small delay or retry logic if needed, but usually awaiting is enough

      // Get mySelf
      final mySelf = await _zoomVideoSdk.session.getMySelf();
      if (mounted) {
        setState(() {
          _mySelf = mySelf;
          _isVideoOn = true;
        });
      }
    } catch (e) {
      print("Error starting preview: $e");
    }
  }

  void _endCallProperly([dynamic result]) {
    _consultationEndFlag = true;
    _zoomVideoSdk.leaveSession(false);
    WakelockPlus.disable();
    Navigator.of(context).pop(result); // Exit screen
  }

  void _showSteppedAwayAlert() {
    // Don't show if in PiP (Flutter PiP detection requires specific plugin logic)
    showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        builder: (context) => Container(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 50, color: Colors.orangeAccent),
                      SizedBox(width: 16),
                      Text("Doctor Stepped Away",
                          style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: Colors.redAccent)),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                      "The doctor has stepped away/left this session. What would you like to do?",
                      textAlign: TextAlign.left,
                      style: GoogleFonts.poppins(
                          fontSize: 16, color: Colors.grey[700])),
                  SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.blue),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: Text("Wait",
                              style: GoogleFonts.poppins(
                                  color: Colors.blue,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _endCallProperly();
                            // _endCallProperly pops the screen, but we might need to be careful about the bottom sheet.
                            // _endCallProperly calls Navigator.pop(context).
                            // Since context is from the class (not builder), it pops the route.
                            // Flutter usually handles popping the top-most (bottom sheet) then route if called correctly.
                            // However, explicit safety:
                            // But _endCallProperly uses 'context' which is the Screen's context, so it pops the Screen.
                            // The BottomSheet is attached to the screen. It should be fine.
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: Text("End Call",
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                      SizedBox(height: 10)
                    ],
                  )
                ],
              ),
            ));
  }

  Future<bool> _onWillPop() async {
    // Show "Are you sure?" bottom sheet
    bool? shouldLeave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          padding: EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 50, color: Colors.orangeAccent),
                    SizedBox(width: 16),
                    Text("Are you sure?",
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: Colors.redAccent)),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                    "Do you want to leave this screen? \nTo return click 'Join Now' from the home screen",
                    textAlign: TextAlign.left,
                    style: GoogleFonts.poppins(
                        fontSize: 16, color: Colors.grey[700])),
                SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.blue),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: Text("No",
                            style: GoogleFonts.poppins(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Perform cleanup manually; don't call _endCallProperly because it tries to pop(context) which is the page context.
                          // We need to pop the dialog with 'true'.
                          _consultationEndFlag = true;
                          _zoomVideoSdk.leaveSession(false);
                          WakelockPlus.disable();
                          Navigator.pop(ctx, true);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: Text("Yes",
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                    SizedBox(height: 10)
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isJoined) {
      return _buildDoctorInfoBackground();
    }

    if (_doctorScreenshareFlag) {
      return _buildScreenShareLayout();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: WillPopScope(

        onWillPop: _onWillPop,
        child: Stack(
          children: [
            // Doctor Video (Full Screen)
            if (_doctorUser != null && _isDoctorVideoOn)
              VideoView(
                key: ValueKey("doc_full_$_videoViewKey"),
                user: _doctorUser!,
                sharing: false,
                preview: false,
                focused: true,
                hasMultiCamera: false,
                isPiPView: false,
                multiCameraIndex: "0",
                videoAspect: VideoAspect.Original,
                fullScreen: true,
                resolution: VideoResolution.Resolution1080,
                displayUserName: widget.consultationModel.doctorName,
              ),

            // "Doctor disabled camera" / Info Background
            if (_doctorUser == null || !_isDoctorVideoOn)
              _buildDoctorInfoBackground(),

            // Transparent Tap Layer for Controls
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleControls,
                child: Container(color: Colors.transparent),
              ),
            ),

            // Self Video (Publisher View)
            if (_isVideoOn && _mySelf != null)
              Positioned(
                top: 50,
                left: 20,
                width: 100,
                height: 110,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: Colors.black, // REQUIRED for SurfaceView
                    child: VideoView(
                      key: ValueKey("self_pip_$_videoViewKey"),
                      user: _mySelf!,
                      preview: true,
                      focused: false,
                      hasMultiCamera: false,
                      sharing: false,
                      isPiPView: true,
                      // 🔥 REQUIRED FOR ZOOM
                      multiCameraIndex: "0",
                      videoAspect: VideoAspect.PanAndScan,
                      // will be ignored
                      fullScreen: false,
                      resolution: VideoResolution.Resolution1080,
                    ),
                  ),
                ),
              ),

            if (!_isVideoOn)
              Positioned(
                top: 50,
                left: 20,
                width: 100,
                height: 110,
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(color: Colors.white, width: 1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Center(
                      child: Icon(Icons.videocam_off,
                          color: Colors.white, size: 30)),
                ),
              ),

            // Controls Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                offset: _showControls ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _buildControls(),
              ),
            ),

            // Recording Indicator (Top Right)
            _buildRecordingIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorInfoBackground() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Center Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Doctor Image
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.grey.shade200, // Placeholder color
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: (widget.consultationModel.doctorImage != null &&
                            widget.consultationModel.doctorImage!.isNotEmpty)
                        ? Image.network(
                            widget.consultationModel.doctorImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                "assets/icons/default-avatar.png",
                                fit: BoxFit.cover,
                              );
                            },
                          )
                        : Image.asset(
                            "assets/icons/default-avatar.png",
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                SizedBox(height: 20),
                // Doctor Name
                Text(
                  widget.consultationModel.doctorName ?? "Doctor",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF102A43), // Dark Blue-Grey
                  ),
                ),
                SizedBox(height: 5),
                // Qualification
                Text(
                  widget.consultationModel.displayEducation ?? "",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF102A43),
                  ),
                ),
                if (widget.consultationModel.status.isNotEmpty) ...[
                  SizedBox(height: 10),
                  Text(
                    widget.consultationModel.status,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Color(0xFF102A43),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Bottom Status Bar - Only show if doctor is NOT present
          if (_doctorUser == null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                    top: 15,
                    bottom: 15 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                  color: Color(0xFFE0E7FF), // Light Indigo/Purple
                  borderRadius: BorderRadius.zero,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(width: 20),
                    // Lottie Animation
                    Container(
                      width: 50,
                      height: 50,
                      child: Lottie.asset(
                        'assets/animations/loader.json',
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      !_isJoined ? "Connecting..." : "Waiting for doctor",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF102A43),
                      ),
                    ),
                  ],
                ),
              ),
            ),

        ],
      ),
    );
  }


  Widget _buildRecordingIndicator() {
    if (!_isRecordingStarted) return SizedBox.shrink();

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Container(
          margin: const EdgeInsets.only(top: 10, right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF232323).withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, color: Colors.red, size: 12),
              SizedBox(width: 8),
              Text(
                "Recording in progress",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return GestureDetector(
      onTap: () {},
      // Prevent tap from propagating to parent (which would toggle controls)
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Color(0xFF333333), // Dark grey background
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor Name
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 20),
              child: Text(
                widget.consultationModel.doctorName ?? "Doctor",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mute/Unmute
                FloatingActionButton(
                  heroTag: "mute",
                  backgroundColor: Color(0xFFE0E7FF),
                  // Light purple/indigo background
                  elevation: 0,
                  onPressed: () {
                    setState(() => _isAudioOn = !_isAudioOn);
                    if (_isAudioOn)
                      _zoomVideoSdk.audioHelper.unMuteAudio(_mySelf!.userId);
                    else
                      _zoomVideoSdk.audioHelper.muteAudio(_mySelf!.userId);
                  },
                  child: Icon(_isAudioOn ? Icons.mic : Icons.mic_off,
                      color: Colors.blue),
                ),
                SizedBox(width: 30),

                // Video On/Off
                FloatingActionButton(
                  heroTag: "video",
                  backgroundColor: Color(0xFFE0E7FF),
                  elevation: 0,
                  onPressed: () {
                    setState(() => _isVideoOn = !_isVideoOn);
                    if (_isVideoOn) {
                      _zoomVideoSdk.videoHelper.startVideo();
                    } else {
                      _zoomVideoSdk.videoHelper.stopVideo();
                    }
                  },
                  child: Icon(_isVideoOn ? Icons.videocam : Icons.videocam_off,
                      color: Colors.blue),
                ),
                SizedBox(width: 30),

                // Switch Camera
                FloatingActionButton(
                  heroTag: "switch",
                  backgroundColor: Color(0xFFE0E7FF),
                  elevation: 0,
                  onPressed: () async {
                    List<ZoomVideoSdkCameraDevice> cameraList =
                        await _zoomVideoSdk.videoHelper.getCameraList();
                    if (cameraList.isEmpty) return;

                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Container(
                        height: 200,
                        child: ListView(
                          children: cameraList
                              .map((camera) => ListTile(
                                    title: Text(camera.deviceName),
                                    onTap: () {
                                      _zoomVideoSdk.videoHelper
                                          .switchCamera(camera.deviceId);
                                      Navigator.pop(context);
                                    },
                                  ))
                              .toList(),
                        ),
                      ),
                    );
                  },
                  child: Icon(Icons.cameraswitch, color: Colors.blue),
                ),
              ],
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenShareLayout() {
    // Replicates ScreenShareFragment
    return Scaffold(
        backgroundColor: Colors.black,
        body: WillPopScope(
            onWillPop: _onWillPop,
            child: Stack(
          children: [
            Row(
              children: [
                // Left Sidebar: Camera Feeds
                Container(
                  width: 150, // Fixed width for the sidebar
                  color: Colors.black,
                  padding: EdgeInsets.only(top: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Doctor Camera Preview (Top)
                      if (_doctorUser != null && _isDoctorVideoOn)
                        Container(
                          width: 130,
                          height: 160,
                          child: VideoView(
                            key: ValueKey("doc_sidebar_$_videoViewKey"),
                            user: _doctorUser!,
                            sharing: false,
                            preview: false,
                            focused: false,
                            hasMultiCamera: false,
                            isPiPView: false,
                            multiCameraIndex: "0",
                            videoAspect: VideoAspect.PanAndScan,
                            fullScreen: false,
                            resolution: VideoResolution.Resolution1080,
                            width: 130, // Pass new width
                            height: 160, // Pass new height
                            displayUserName: widget.consultationModel.doctorName,
                          ),
                        ),

                      // Doctor Camera Off / Avatar (Top)
                      if (_doctorUser != null && !_isDoctorVideoOn)
                        Container(
                          width: 130,
                          height: 160,
                          decoration: BoxDecoration(
                              color: Colors.black,
                              border: Border.all(color: Colors.white)),
                          child: Icon(Icons.videocam_off, color: Colors.red),
                        ),

                      SizedBox(height: 10), // Spacing between videos

                      // Self Video Overlay (Bottom)
                      if (_isVideoOn && _mySelf != null)
                        Container(
                          width: 130,
                          height: 160,
                          child: RotatedBox(
                            quarterTurns: _selfViewRotation,
                            child: VideoView(
                              key: ValueKey("self_sidebar_$_videoViewKey"),
                              user: _mySelf!,
                              preview: true,
                              focused: false,
                              hasMultiCamera: false,
                              sharing: false,
                              isPiPView: false,
                              multiCameraIndex: "0",
                              videoAspect: VideoAspect.FullFilled, // Ensures it fills the portrait container
                              fullScreen: false,
                              resolution: VideoResolution.Resolution1080,
                              width: 160,
                              height: 130,
                            ),
                          ),
                        ),

                      // "Camera Off" Icon (Bottom - matches Self Video position)
                      if (!_isVideoOn)
                        Container(
                          width: 130,
                          height: 160,
                          decoration: BoxDecoration(
                              color: Colors.black,
                              border: Border.all(color: Colors.white)),
                          child: Icon(Icons.videocam_off, color: Colors.red),
                        ),

                      // // Debug Info (Remove later)
                      // SizedBox(height: 10),
                      // Text(
                      //   "R:$_selfViewRotation | F:$_doctorScreenshareFlag | K:$_videoViewKey",
                      //   style: TextStyle(color: Colors.yellow, fontSize: 10),
                      // ),
                    ],
                  ),
                ),
            
            // Right Side: Screen Share (Main Content)
            if (_doctorUser != null)
              Expanded(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 1.0,
                  maxScale: 5.0,
                  onInteractionEnd: (details) {
                    // Optional: Reset logic if needed
                  },
                  child: VideoView(
                    key: ValueKey("share_main_$_videoViewKey"),
                    user: _doctorUser!,
                    sharing: true,
                    // IMPORTANT: Enable sharing view
                    preview: false,
                    focused: true,
                    hasMultiCamera: false,
                    isPiPView: false,
                    multiCameraIndex: "0",
                    videoAspect: VideoAspect.Original, // Keep original aspect for readable text
                    fullScreen: true,
                    resolution: VideoResolution.Resolution1080,
                  ),
                ),
              ),
            ],
            ),
            // Recording Indicator
            _buildRecordingIndicator(),
          ],
        )));
  }
}
