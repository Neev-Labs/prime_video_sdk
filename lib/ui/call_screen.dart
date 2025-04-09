import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_event_listener.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_user.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_share_action.dart';
import '../components/video_view.dart';
import '../model/models.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_camera_device.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_live_transcription_message_info.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class CallArguments {
  final bool isJoin;
  final String sessionName;
  final String token;
  final String sessionPwd;
  final String displayName;
  final String sessionIdleTimeoutMins;
  final String role;

  CallArguments(this.sessionName, this.token, this.sessionPwd, this.displayName,
      this.sessionIdleTimeoutMins, this.role, this.isJoin);
}

class CallScreen extends StatefulHookWidget {
  final CallArguments callArguments;

  const CallScreen({Key? key, required this.callArguments}) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  double opacityLevel = 1.0;
  var zoom = ZoomVideoSdk();

  void _changeOpacity() {
    setState(() => opacityLevel = opacityLevel == 0 ? 1.0 : 0.0);
  }

  @override
  void initState() {
    WakelockPlus.enable();
    super.initState();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  void leaveConsultation() async {
    try {
      await zoom.videoHelper.stopVideo();
      await zoom.audioHelper.stopAudio();
      await zoom.leaveSession(false);
      await zoom.cleanup();
      Navigator.of(context, rootNavigator: true).pop(true);
    } catch (e) {
      print("Error while leaving Zoom session: $e");
      Navigator.of(context, rootNavigator: true).pop(true);
    }
  }

  void consultationEndAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Consultation Ended'),
          content: Text('The consultation has ended'),
          actions: [
            TextButton(
              onPressed: () => leaveConsultation(),
              child: Text('Goto Home'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var zoom = ZoomVideoSdk();
    InitConfig initConfig = InitConfig(
      domain: "zoom.us",
      enableLog: true,
    );
    zoom.initSdk(initConfig);

    var eventListener = ZoomVideoSdkEventListener();
    var isInSession = useState(false);
    var sessionName = useState('');
    var sessionPassword = useState('');
    var users = useState(<ZoomVideoSdkUser>[]);
    var fullScreenUser = useState<ZoomVideoSdkUser?>(null);
    var sharingUser = useState<ZoomVideoSdkUser?>(null);
    var connectionStatus = useState<String>('');
    var isSharing = useState(false);
    var isMuted = useState(true);
    var isVideoOn = useState(false);
    var isSpeakerOn = useState(false);
    var leaveClicked = useState(false);
    var isRecordingStarted = useState(false);
    var isMounted = useIsMounted();
    var audioStatusFlag = useState(false);
    var videoStatusFlag = useState(false);
    var userNameFlag = useState(false);
    var userShareStatusFlag = useState(false);
    var isReceiveSpokenLanguageContentEnabled = useState(false);
    var isPiPView = useState(false);

    //hide status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
    var circleButtonSize = 65.0;
    Color backgroundColor = const Color(0xFF232323);
    Color buttonBackgroundColor = const Color.fromRGBO(0, 0, 0, 0.6);
    Color chatTextColor = const Color(0xFFAAAAAA);
    Widget changeNamePopup;
    // final args = ModalRoute.of(context)!.settings.arguments as CallArguments;

    useEffect(() {
      Future<void>.microtask(() async {
        try {
          Map<String, bool> SDKaudioOptions = {
            "connect": true,
            "mute": true,
            "autoAdjustSpeakerVolume": false
          };
          Map<String, bool> SDKvideoOptions = {
            "localVideoOn": true,
          };
          JoinSessionConfig joinSession = JoinSessionConfig(
            sessionName: widget.callArguments.sessionName,
            sessionPassword: '',
            token: widget.callArguments.token,
            userName: 'Patient',
            audioOptions: SDKaudioOptions,
            videoOptions: SDKvideoOptions,
            sessionIdleTimeoutMins: int.parse('40'),
          );
          connectionStatus.value = 'Connecting...';
          await zoom.joinSession(joinSession);
        } catch (e) {
          const AlertDialog(
            title: Text("Error"),
            content: Text("Failed to join the session"),
          );
          Future.delayed(const Duration(milliseconds: 1000))
              .asStream()
              .listen((event) {});
        }
      });
      return null;
    }, []);

    useEffect(() {
      bool isPopupVisible = false;

      final sessionJoinListener =
      eventListener.addListener(EventType.onSessionJoin, (data) async {
        connectionStatus.value = 'Waiting for doctor';
        data = data as Map;
        isInSession.value = true;
        zoom.session
            .getSessionName()
            .then((value) => sessionName.value = value!);
        sessionPassword.value = await zoom.session.getSessionPassword();
        debugPrint(
            "sessionPhonePasscode: ${await zoom.session.getSessionPhonePasscode()}");
        ZoomVideoSdkUser mySelf =
        ZoomVideoSdkUser.fromJson(jsonDecode(data['sessionUser']));
        List<ZoomVideoSdkUser>? remoteUsers =
        await zoom.session.getRemoteUsers();
        var muted = await mySelf.audioStatus?.isMuted();
        var videoOn = await mySelf.videoStatus?.isOn();
        var speakerOn = await zoom.audioHelper.getSpeakerStatus();
        if (remoteUsers != null) {
          for (var user in remoteUsers) {
            if (user.userName == 'Web_Doctor') {
              fullScreenUser.value = user;
              if (await user.videoStatus?.isOn() == false) {
                videoStatusFlag.value = false;
              }
            }
          }
        }
        List<ZoomVideoSdkUser>? remoteUsersList = [];
        remoteUsersList.insert(0, mySelf);
        isMuted.value = muted!;
        isSpeakerOn.value = speakerOn;
        isVideoOn.value = videoOn!;
        users.value = remoteUsersList;
        isReceiveSpokenLanguageContentEnabled.value = await zoom
            .liveTranscriptionHelper
            .isReceiveSpokenLanguageContentEnabled();
      });
      final sessionLeaveListener =
      eventListener.addListener(EventType.onSessionLeave, (data) async {
        data = data as Map;
        debugPrint("onSessionLeave: ${data['reason']}");
        isInSession.value = false;
        users.value = <ZoomVideoSdkUser>[];
        fullScreenUser.value = null;
        await zoom.cleanup();
        Navigator.of(context, rootNavigator: true).pop(true);
      });

      final sessionNeedPasswordListener = eventListener
          .addListener(EventType.onSessionNeedPassword, (data) async {
        showDialog<String>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Session Need Password'),
            content: const Text('Password is required'),
            actions: <Widget>[
              TextButton(
                onPressed: () async => {
                  await zoom.leaveSession(false),
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });

      final sessionPasswordWrongListener = eventListener
          .addListener(EventType.onSessionPasswordWrong, (data) async {
        showDialog<String>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Session Password Incorrect'),
            content: const Text('Password is wrong'),
            actions: <Widget>[
              TextButton(
                onPressed: () async => {
                  await zoom.leaveSession(false),
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });

      final userVideoStatusChangedListener = eventListener
          .addListener(EventType.onUserVideoStatusChanged, (data) async {
        data = data as Map;
        ZoomVideoSdkUser? mySelf = await zoom.session.getMySelf();
        var userListJson = jsonDecode(data['changedUsers']) as List;
        List<ZoomVideoSdkUser> userList = userListJson
            .map((userJson) => ZoomVideoSdkUser.fromJson(userJson))
            .toList();
        for (var user in userList) {
          {
            if (user.userId == mySelf?.userId) {
              mySelf?.videoStatus?.isOn().then((on) => isVideoOn.value = on);
            }
          }
        }
        videoStatusFlag.value = !videoStatusFlag.value;
      });

      final userAudioStatusChangedListener = eventListener
          .addListener(EventType.onUserAudioStatusChanged, (data) async {
        data = data as Map;
        ZoomVideoSdkUser? mySelf = await zoom.session.getMySelf();
        var userListJson = jsonDecode(data['changedUsers']) as List;
        List<ZoomVideoSdkUser> userList = userListJson
            .map((userJson) => ZoomVideoSdkUser.fromJson(userJson))
            .toList();
        for (var user in userList) {
          {
            if (user.userId == mySelf?.userId) {
              mySelf?.audioStatus
                  ?.isMuted()
                  .then((muted) => isMuted.value = muted);
            }
          }
        }
        audioStatusFlag.value = !audioStatusFlag.value;
      });

      final userShareStatusChangeListener = eventListener
          .addListener(EventType.onUserShareStatusChanged, (data) async {
        data = data as Map;
        ZoomVideoSdkUser? mySelf = await zoom.session.getMySelf();
        ZoomVideoSdkUser shareUser =
        ZoomVideoSdkUser.fromJson(jsonDecode(data['user'].toString()));
        ZoomVideoSdkShareAction? shareAction =
        ZoomVideoSdkShareAction.fromJson(jsonDecode(data['shareAction']));

        if (shareAction.shareStatus == ShareStatus.Start ||
            shareAction.shareStatus == ShareStatus.Resume) {
          sharingUser.value = shareUser;
          fullScreenUser.value = shareUser;
          isSharing.value = (shareUser.userId == mySelf?.userId);
          List<ZoomVideoSdkUser>? remoteUsers =
          await zoom.session.getRemoteUsers();
          remoteUsers?.insert(0, mySelf!);
          users.value = remoteUsers!;
        } else {
          sharingUser.value = null;
          isSharing.value = false;
          fullScreenUser.value = shareUser;
          List<ZoomVideoSdkUser>? remoteUsers = [];
          remoteUsers.insert(0, mySelf!);
          users.value = remoteUsers;
        }
        userShareStatusFlag.value = !userShareStatusFlag.value;
      });

      final userJoinListener =
      eventListener.addListener(EventType.onUserJoin, (data) async {
        if (!isMounted()) return;
        data = data as Map;
        ZoomVideoSdkUser? mySelf = await zoom.session.getMySelf();
        var userListJson = jsonDecode(data['remoteUsers']) as List;
        List<ZoomVideoSdkUser> remoteUserList = userListJson
            .map((userJson) => ZoomVideoSdkUser.fromJson(userJson))
            .toList();
        for (var user in remoteUserList) {
          if (user.userName == 'Web_Doctor') {
            fullScreenUser.value = user;
          }
        }
        List<ZoomVideoSdkUser>? remoteUsers = [];
        remoteUsers.insert(0, mySelf!);
        users.value = remoteUsers;
      });

      void showLeftDialog(BuildContext context) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Doctor is away'),
              content: Text(
                  'The doctor has stepped away/left this session. What would you like to do?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Wait'),
                ),
              ],
            );
          },
        );
      }

      final userLeaveListener =
      eventListener.addListener(EventType.onUserLeave, (data) async {
        if (!isMounted()) return;
        debugPrint("data: $data");
        data = data as Map;
        connectionStatus.value = 'The doctor has left this session';
        var leftUserListJson = jsonDecode(data['leftUsers']) as List;
        for (var user in leftUserListJson) {
          final userMap = user as Map<String, dynamic>;
          if (userMap['userName'] == 'Web_Doctor') {
            Future.delayed(Duration(seconds: 1), () {
              if (isInSession.value &&
                  !leaveClicked.value &&
                  data['reason'] == null) {
                isPopupVisible = true;
                connectionStatus.value =
                'The doctor has stepped\naway/left this session';
                showLeftDialog(context);
                fullScreenUser.value = null;
              }
            });
            break;
          }
        }
      });

      final userNameChangedListener =
      eventListener.addListener(EventType.onUserNameChanged, (data) async {
        if (!isMounted()) return;
        data = data as Map;
        ZoomVideoSdkUser? changedUser =
        ZoomVideoSdkUser.fromJson(jsonDecode(data['changedUser']));
        int index;
        for (var user in users.value) {
          if (user.userId == changedUser.userId) {
            index = users.value.indexOf(user);
            users.value[index] = changedUser;
          }
        }
        userNameFlag.value = !userNameFlag.value;
      });

      final commandReceived =
      eventListener.addListener(EventType.onCommandReceived, (data) async {
        data = data as Map;
        debugPrint(
            "sender: ${ZoomVideoSdkUser.fromJson(jsonDecode(data['sender']))}, command: ${data['command']}");
      });

      final liveStreamStatusChangeListener = eventListener
          .addListener(EventType.onLiveStreamStatusChanged, (data) async {
        data = data as Map;
        debugPrint("onLiveStreamStatusChanged: status: ${data['status']}");
      });

      final liveTranscriptionStatusChangeListener = eventListener
          .addListener(EventType.onLiveTranscriptionStatus, (data) async {
        data = data as Map;
        debugPrint("onLiveTranscriptionStatus: status: ${data['status']}");
      });

      final cloudRecordingStatusListener = eventListener
          .addListener(EventType.onCloudRecordingStatus, (data) async {
        data = data as Map;
        debugPrint("onCloudRecordingStatus: status: ${data['status']}");
        ZoomVideoSdkUser? mySelf = await zoom.session.getMySelf();
        if (data['status'] == RecordingStatus.Start) {
          if (mySelf != null && !mySelf.isHost!) {
            showDialog<String>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                content: const Text('The call is being recorded.'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () async {
                      await zoom.acceptRecordingConsent();
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                      ;
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          isRecordingStarted.value = true;
        } else {
          isRecordingStarted.value = false;
        }
      });

      final liveTranscriptionMsgInfoReceivedListener = eventListener
          .addListener(EventType.onLiveTranscriptionMsgInfoReceived,
              (data) async {
            data = data as Map;
            ZoomVideoSdkLiveTranscriptionMessageInfo? messageInfo =
            ZoomVideoSdkLiveTranscriptionMessageInfo.fromJson(
                jsonDecode(data['messageInfo']));
            debugPrint(
                "onLiveTranscriptionMsgInfoReceived: content: ${messageInfo.messageContent}");
          });

      final inviteByPhoneStatusListener = eventListener
          .addListener(EventType.onInviteByPhoneStatus, (data) async {
        data = data as Map;
        debugPrint(
            "onInviteByPhoneStatus: status: ${data['status']}, reason: ${data['reason']}");
      });

      final multiCameraStreamStatusChangedListener = eventListener.addListener(
          EventType.onMultiCameraStreamStatusChanged, (data) async {
        data = data as Map;
        ZoomVideoSdkUser? changedUser =
        ZoomVideoSdkUser.fromJson(jsonDecode(data['changedUser']));
        var status = data['status'];
        for (var user in users.value) {
          {
            if (changedUser.userId == user.userId) {
              if (status == MultiCameraStreamStatus.Joined) {
                user.hasMultiCamera = true;
              } else if (status == MultiCameraStreamStatus.Left) {
                user.hasMultiCamera = false;
              }
            }
          }
        }
      });

      final requireSystemPermission = eventListener
          .addListener(EventType.onRequireSystemPermission, (data) async {
        data = data as Map;
        ZoomVideoSdkUser? changedUser =
        ZoomVideoSdkUser.fromJson(jsonDecode(data['changedUser']));
        var permissionType = data['permissionType'];
        switch (permissionType) {
          case SystemPermissionType.Camera:
            showDialog<String>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Text("Can't Access Camera"),
                content: const Text(
                    "please turn on the toggle in system settings to grant permission"),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'OK'),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            break;
          case SystemPermissionType.Microphone:
            showDialog<String>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Text("Can't Access Microphone"),
                content: const Text(
                    "please turn on the toggle in system settings to grant permission"),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'OK'),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            break;
        }
      });

      final networkStatusChangeListener = eventListener
          .addListener(EventType.onUserVideoNetworkStatusChanged, (data) async {
        data = data as Map;
        ZoomVideoSdkUser? networkUser =
        ZoomVideoSdkUser.fromJson(jsonDecode(data['user']));

        if (data['status'] == NetworkStatus.Bad) {
          debugPrint(
              "onUserVideoNetworkStatusChanged: status: ${data['status']}, user: ${networkUser.userName}");
        }
      });

      final eventErrorListener =
      eventListener.addListener(EventType.onError, (data) async {
        data = data as Map;
        String errorType = data['errorType'];
        showDialog<String>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text("Error"),
            content: Text(errorType),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, 'OK'),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (errorType == Errors.SessionJoinFailed ||
            errorType == Errors.SessionDisconnecting) {
          Timer(const Duration(milliseconds: 1000),
                  () => {Navigator.of(context).pop(true)});
        }
      });

      final userRecordingConsentListener = eventListener
          .addListener(EventType.onUserRecordingConsent, (data) async {
        data = data as Map;
        ZoomVideoSdkUser? user =
        ZoomVideoSdkUser.fromJson(jsonDecode(data['user']));
        debugPrint('userRecordingConsentListener: user= ${user.userName}');
      });

      final callCRCDeviceStatusListener = eventListener
          .addListener(EventType.onCallCRCDeviceStatusChanged, (data) async {
        data = data as Map;
        debugPrint('onCallCRCDeviceStatusChanged: status = ${data['status']}');
      });

      final originalLanguageMsgReceivedListener = eventListener
          .addListener(EventType.onOriginalLanguageMsgReceived, (data) async {
        data = data as Map;
        ZoomVideoSdkLiveTranscriptionMessageInfo? messageInfo =
        ZoomVideoSdkLiveTranscriptionMessageInfo.fromJson(
            jsonDecode(data['messageInfo']));
        debugPrint(
            "onOriginalLanguageMsgReceived: content: ${messageInfo.messageContent}");
      });

      final chatPrivilegeChangedListener = eventListener
          .addListener(EventType.onChatPrivilegeChanged, (data) async {
        data = data as Map;
        String type = data['privilege'];
        debugPrint('chatPrivilegeChangedListener: type= $type');
      });

      final testMicStatusListener = eventListener
          .addListener(EventType.onTestMicStatusChanged, (data) async {
        data = data as Map;
        String status = data['status'];
        debugPrint('testMicStatusListener: status= $status');
      });

      final micSpeakerVolumeChangedListener = eventListener
          .addListener(EventType.onMicSpeakerVolumeChanged, (data) async {
        data = data as Map;
        int type = data['micVolume'];
        debugPrint(
            'onMicSpeakerVolumeChanged: micVolume= $type, speakerVolume');
      });

      final cameraControlRequestResultListener = eventListener
          .addListener(EventType.onCameraControlRequestResult, (data) async {
        data = data as Map;
        bool approved = data['approved'];
        debugPrint('onCameraControlRequestResult: approved= $approved');
      });

      final callOutUserJoinListener = eventListener
          .addListener(EventType.onCalloutJoinSuccess, (data) async {
        data = data as Map;
        String phoneNumber = data['phoneNumber'];
        ZoomVideoSdkUser? user =
        ZoomVideoSdkUser.fromJson(jsonDecode(data['user']));
        debugPrint(
            'onCalloutJoinSuccess: phoneNumber= $phoneNumber, user= ${user.userName}');
      });

      return () => {
        sessionJoinListener.cancel(),
        sessionLeaveListener.cancel(),
        sessionPasswordWrongListener.cancel(),
        sessionNeedPasswordListener.cancel(),
        userVideoStatusChangedListener.cancel(),
        userAudioStatusChangedListener.cancel(),
        userJoinListener.cancel(),
        userLeaveListener.cancel(),
        userNameChangedListener.cancel(),
        userShareStatusChangeListener.cancel(),
        liveStreamStatusChangeListener.cancel(),
        cloudRecordingStatusListener.cancel(),
        inviteByPhoneStatusListener.cancel(),
        eventErrorListener.cancel(),
        commandReceived.cancel(),
        liveTranscriptionStatusChangeListener.cancel(),
        liveTranscriptionMsgInfoReceivedListener.cancel(),
        multiCameraStreamStatusChangedListener.cancel(),
        requireSystemPermission.cancel(),
        userRecordingConsentListener.cancel(),
        networkStatusChangeListener.cancel(),
        callCRCDeviceStatusListener.cancel(),
        originalLanguageMsgReceivedListener.cancel(),
        chatPrivilegeChangedListener.cancel(),
        testMicStatusListener.cancel(),
        micSpeakerVolumeChangedListener.cancel(),
        cameraControlRequestResultListener.cancel(),
        callOutUserJoinListener.cancel(),
      };
    }, [zoom, users.value, isMounted]);

    void onPressAudio() async {
      ZoomVideoSdkUser? mySelf = await zoom.session.getMySelf();
      if (mySelf != null) {
        final audioStatus = mySelf.audioStatus;
        if (audioStatus != null) {
          var muted = await audioStatus.isMuted();
          if (muted) {
            await zoom.audioHelper.unMuteAudio(mySelf.userId);
          } else {
            await zoom.audioHelper.muteAudio(mySelf.userId);
          }
        }
      }
    }

    void onPressVideo() async {
      ZoomVideoSdkUser? mySelf = await zoom.session.getMySelf();
      if (mySelf != null) {
        final videoStatus = mySelf.videoStatus;
        if (videoStatus != null) {
          var videoOn = await videoStatus.isOn();
          if (videoOn) {
            await zoom.videoHelper.stopVideo();
          } else {
            await zoom.videoHelper.startVideo();
          }
        }
      }
    }

    void leaveConsultation() async {
      try {
        await zoom.videoHelper.stopVideo();
        await zoom.audioHelper.stopAudio();
        leaveClicked.value = true;
        await zoom.leaveSession(false);
        await zoom.cleanup();

        Navigator.of(context, rootNavigator: true).pop(true);
      } catch (e) {
        print("Error while leaving Zoom session: $e");
      }
    }

    void onPressCameraList() async {
      List<ListTile> options = [];
      List<ZoomVideoSdkCameraDevice> cameraList =
      await zoom.videoHelper.getCameraList();
      for (var camera in cameraList) {
        options.add(
          ListTile(
            title: Text(
              camera.deviceName,
              style: GoogleFonts.lato(
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
              ),
            ),
            onTap: () async => {
              await zoom.videoHelper.switchCamera(camera.deviceId),
              Navigator.of(context).pop(),
            },
          ),
        );
      }
      options.add(
        ListTile(
          title: Text(
            "Cancel",
            style: GoogleFonts.lato(
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
          onTap: () async => {
            Navigator.of(context).pop(),
          },
        ),
      );
      showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              elevation: 0.0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 40),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: SizedBox(
                height: options.length * 60,
                child: Scrollbar(
                  child: ListView(
                    shrinkWrap: true,
                    scrollDirection: Axis.vertical,
                    children: ListTile.divideTiles(
                      context: context,
                      tiles: options,
                    ).toList(),
                  ),
                ),
              ),
            );
          });
    }

    void onLeaveSession(bool isEndSession) async {
      await zoom.leaveSession(isEndSession);
    }

    void showLeaveOptions() async {
      ZoomVideoSdkUser? mySelf = await zoom.session.getMySelf();
      bool isHost = await mySelf!.getIsHost();

      Widget endSession;
      Widget leaveSession;
      Widget cancel = TextButton(
        child: const Text('Cancel'),
        onPressed: () {
          Navigator.pop(context); //close Dialog
        },
      );

      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          endSession = TextButton(
            child: const Text('End Session'),
            onPressed: () => onLeaveSession(true),
          );
          leaveSession = TextButton(
            child: const Text('Leave Session'),
            onPressed: () => onLeaveSession(false),
          );
          break;
        default:
          endSession = CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('End Session'),
            onPressed: () => onLeaveSession(true),
          );
          leaveSession = CupertinoActionSheetAction(
            child: const Text('Leave Session'),
            onPressed: () => onLeaveSession(false),
          );
          break;
      }

      List<Widget> options = [
        leaveSession,
        cancel,
      ];

      if (Platform.isAndroid) {
        if (isHost) {
          options.removeAt(1);
          options.insert(0, endSession);
        }
        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                content: const Text("Do you want to leave this session?"),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(2.0))),
                actions: options,
              );
            });
      } else {
        options.removeAt(1);
        if (isHost) {
          options.insert(1, endSession);
        }
        showCupertinoModalPopup(
          context: context,
          builder: (context) => CupertinoActionSheet(
            message:
            const Text('Are you sure that you want to leave the session?'),
            actions: options,
            cancelButton: cancel,
          ),
        );
      }
    }

    final chatMessageController = TextEditingController();

    void sendChatMessage(String message) async {
      await zoom.chatHelper.sendChatToAll(message);
      ZoomVideoSdkUser? self = await zoom.session.getMySelf();
      for (var user in users.value) {
        if (user.userId != self?.userId) {
          await zoom.cmdChannel.sendCommand(user.userId, message);
        }
      }
      chatMessageController.clear();
      // send the chat as a command
    }

    void onSelectedUser(ZoomVideoSdkUser user) async {
      setState(() {
        fullScreenUser.value = user;
      });
    }

    Widget fullScreenView;
    Widget smallView;
    if (users.value.isNotEmpty) {
      smallView = Container(
        height: 110,
        margin: const EdgeInsets.only(left: 20, right: 20),
        alignment: Alignment.center,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: users.value.length,
          itemBuilder: (BuildContext context, int index) {
            return InkWell(
              child: Center(
                child: VideoView(
                  user: users.value[index],
                  hasMultiCamera: false,
                  isPiPView: false,
                  sharing: false,
                  preview: false,
                  focused: false,
                  multiCameraIndex: "0",
                  videoAspect: VideoAspect.Original,
                  fullScreen: false,
                  resolution: VideoResolution.Resolution180,
                ),
              ),
            );
          },
          separatorBuilder: (BuildContext context, int index) =>
          const Divider(),
        ),
      );
    } else {
      smallView = Container(
        height: 110,
        color: Colors.transparent,
      );
    }

    if (isInSession.value && fullScreenUser.value != null) {
      fullScreenView = AnimatedOpacity(
        opacity: opacityLevel,
        duration: const Duration(seconds: 3),
        child: VideoView(
          user: fullScreenUser.value,
          hasMultiCamera: false,
          isPiPView: isPiPView.value,
          sharing: sharingUser.value == null
              ? false
              : (sharingUser.value?.userId == fullScreenUser.value?.userId),
          preview: false,
          focused: false,
          multiCameraIndex: "0",
          videoAspect: VideoAspect.Original,
          fullScreen: true,
          resolution: VideoResolution.Resolution360,
        ),
      );
    } else {
      fullScreenView = Container(
          color: Colors.black,
          child: Center(
            child: Text(
              connectionStatus.value,
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ));
    }

    _changeOpacity;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        bool exitApp = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Are you sure?"),
            content: Text(
                "Do you want to leave this screen? \nTo return click 'Join Now' from the home screen"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text("Cancel"),
              ),
              TextButton(
                onPressed: leaveConsultation,
                child: Text("Yes"),
              ),
            ],
          ),
        ) ??
            false;

        if (exitApp) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: backgroundColor,
          body: Stack(
            children: [
              fullScreenView,
              Container(
                  padding: const EdgeInsets.only(top: 35),
                  child: Stack(
                    children: [
                      Align(
                          alignment: Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: 0.2,
                            heightFactor: 0.6,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: onPressAudio,
                                  icon: isMuted.value
                                      ? Image.asset(
                                      "assets/icons/unmute@2x.png")
                                      : Image.asset("assets/icons/mute@2x.png"),
                                  iconSize: circleButtonSize,
                                  tooltip:
                                  isMuted.value == true ? "Unmute" : "Mute",
                                ),
                                IconButton(
                                  onPressed: onPressVideo,
                                  iconSize: circleButtonSize,
                                  icon: isVideoOn.value
                                      ? Image.asset(
                                      "assets/icons/video-off@2x.png")
                                      : Image.asset(
                                      "assets/icons/video-on@2x.png"),
                                ),
                                IconButton(
                                  onPressed: onPressCameraList,
                                  icon: Image.asset("assets/icons/more@2x.png"),
                                  iconSize: circleButtonSize,
                                ),
                              ],
                            ),
                          )),
                      Container(
                        alignment: Alignment.bottomLeft,
                        margin: const EdgeInsets.only(bottom: 120),
                        child: smallView,
                      ),
                    ],
                  )),
            ],
          )),
    );
  }
}
