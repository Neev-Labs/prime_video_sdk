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
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  double opacityLevel = 1.0;

  void _changeOpacity() {
    setState(() => opacityLevel = opacityLevel == 0 ? 1.0 : 0.0);
  }

  @override
  Widget build(BuildContext context) {
    var zoom = ZoomVideoSdk();
    var eventListener = ZoomVideoSdkEventListener();
    var isInSession = useState(false);
    var sessionName = useState('');
    var sessionPassword = useState('');
    var users = useState(<ZoomVideoSdkUser>[]);
    var fullScreenUser = useState<ZoomVideoSdkUser?>(null);
    var sharingUser = useState<ZoomVideoSdkUser?>(null);
    var videoInfo = useState<String>('');
    var isSharing = useState(false);
    var isMuted = useState(true);
    var isVideoOn = useState(false);
    var isSpeakerOn = useState(false);
    var isRenameModalVisible = useState(false);
    var isRecordingStarted = useState(false);
    var isMicOriginalOn = useState(false);
    var isMounted = useIsMounted();
    var audioStatusFlag = useState(false);
    var videoStatusFlag = useState(false);
    var statusText = useState<String>('Connecting...');
    var userNameFlag = useState(false);
    var userShareStatusFlag = useState(false);
    var isReceiveSpokenLanguageContentEnabled = useState(false);
    var isVideoMirrored = useState(false);
    var isOriginalAspectRatio = useState(false);
    var isPiPView = useState(false);

    //hide status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
    var circleButtonSize = 65.0;
    Color backgroundColor = const Color(0xFF232323);
    Color buttonBackgroundColor = const Color.fromRGBO(0, 0, 0, 0.6);
    Color chatTextColor = const Color(0xFFAAAAAA);
    Widget changeNamePopup;
    final args = ModalRoute.of(context)!.settings.arguments as CallArguments;

    useEffect(() {
      Future<void>.microtask(() async {
        // var token = generateJwt(args.sessionName, args.role);
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
            sessionName: args.sessionName,
            sessionPassword: '',
            token: args.token,
            userName: 'Patient',
            audioOptions: SDKaudioOptions,
            videoOptions: SDKvideoOptions,
            sessionIdleTimeoutMins: int.parse('40'),
          );
          await zoom.joinSession(joinSession);
        } catch (e) {
          print(e);
          print('zoom errppppr${args.sessionName} ${args.token}');
        }
      });
      return null;
    }, []);

    useEffect(() {
      final sessionJoinListener =
      eventListener.addListener(EventType.onSessionJoin, (data) async {
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

        statusText.value = 'Waiting for doctor';
        for (ZoomVideoSdkUser user in remoteUsers ?? []) {
          if (user.userName.contains('Patient')) {
          } else {
            fullScreenUser.value = user;
          }
        }
        var muted = await mySelf.audioStatus?.isMuted();
        var videoOn = await mySelf.videoStatus?.isOn();
        var speakerOn = await zoom.audioHelper.getSpeakerStatus();
        List<ZoomVideoSdkUser>? remoteUser = [];
        remoteUser.insert(0, mySelf);
        isMuted.value = muted!;
        isSpeakerOn.value = speakerOn;
        isVideoOn.value = videoOn!;
        users.value = remoteUser;
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
        Navigator.of(context).pop(true);
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
                  Navigator.of(context).pop(true),
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
                  Navigator.of(context).pop(true),
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
        } else {
          sharingUser.value = null;
          isSharing.value = false;
          fullScreenUser.value = mySelf;
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
        print(remoteUserList);
        for (ZoomVideoSdkUser user in remoteUserList) {
          if (user.userName.contains('Patient')) {
            statusText.value = 'Waiting for doctor';
          } else {
            fullScreenUser.value = user;
          }
        }
        List<ZoomVideoSdkUser> remoteUserLists = [];
        remoteUserLists.insert(0, mySelf!);
        users.value = remoteUserLists;
      });
      void onLeaveSession(bool isEndSession) async {
        await zoom.leaveSession(isEndSession);
      }

      void leaveConsultation() {
        onLeaveSession(false);
      }

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
                TextButton(
                  onPressed: leaveConsultation,
                  child: Text('End this call'),
                ),
              ],
            );
          },
        );
      }

      final userLeaveListener =
      eventListener.addListener(EventType.onUserLeave, (data) async {
        if (!isMounted()) return;
        ZoomVideoSdkUser? mySelf = await zoom.session.getMySelf();
        data = data as Map;
        List<ZoomVideoSdkUser>? remoteUserList =
        await zoom.session.getRemoteUsers();
        var leftUserListJson = jsonDecode(data['leftUsers']) as List;
        List<ZoomVideoSdkUser> leftUserLis = leftUserListJson
            .map((userJson) => ZoomVideoSdkUser.fromJson(userJson))
            .toList();
        for (ZoomVideoSdkUser user in remoteUserList ?? []) {
          if (user.userName.contains('Patient')) {
            statusText.value = 'Doctor left from consultation';
            showLeftDialog(context);
          } else {
            fullScreenUser.value = null;
          }
        }

        List<ZoomVideoSdkUser> remoteUserLists = [];
        remoteUserLists.insert(0, mySelf!);
        users.value = remoteUserLists;
      });

      final commandReceived =
      eventListener.addListener(EventType.onCommandReceived, (data) async {
        data = data as Map;
        debugPrint(
            "sender: ${ZoomVideoSdkUser.fromJson(jsonDecode(data['sender']))}, command: ${data['command']}");
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
          Timer(
              const Duration(milliseconds: 1000),
                  () {
                Navigator.of(context).pop(true);
              });
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

      return () => {
        sessionJoinListener.cancel(),
        sessionLeaveListener.cancel(),
        sessionPasswordWrongListener.cancel(),
        sessionNeedPasswordListener.cancel(),
        userVideoStatusChangedListener.cancel(),
        userAudioStatusChangedListener.cancel(),
        userJoinListener.cancel(),
        userLeaveListener.cancel(),
        userShareStatusChangeListener.cancel(),
        eventErrorListener.cancel(),
        commandReceived.cancel(),
        requireSystemPermission.cancel(),
        userRecordingConsentListener.cancel(),
        networkStatusChangeListener.cancel(),
        callCRCDeviceStatusListener.cancel(),
      };
    }, [zoom, users.value, isMounted]);

    void selectVirtualBackgroundItem() async {
      // final ImagePicker picker = ImagePicker();
      // // Pick an image.
      // final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      // await zoom.virtualBackgroundHelper.addVirtualBackgroundItem(image!.path);
    }

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

    Future<void> onPressMore() async {
      ZoomVideoSdkUser? mySelf = await zoom.session.getMySelf();
      bool isShareLocked = await zoom.shareHelper.isShareLocked();
      bool canSwitchSpeaker = await zoom.audioHelper.canSwitchSpeaker();
      bool canStartRecording =
          (await zoom.recordingHelper.canStartRecording()) == Errors.Success;
      var startLiveTranscription =
          (await zoom.liveTranscriptionHelper.getLiveTranscriptionStatus()) ==
              LiveTranscriptionStatus.Start;
      bool canStartLiveTranscription =
      await zoom.liveTranscriptionHelper.canStartLiveTranscription();
      bool isHost = (mySelf != null) ? (await mySelf.getIsHost()) : false;
      isOriginalAspectRatio.value =
      await zoom.videoHelper.isOriginalAspectRatioEnabled();
      bool canCallOutToCRC = await zoom.CRCHelper.isCRCEnabled();
      bool supportVB =
      await zoom.virtualBackgroundHelper.isSupportVirtualBackground();
      String? shareStatus = await mySelf?.getShareStatus();

      List<ListTile> options = [
        ListTile(
          title: Text(
            'More',
            style: GoogleFonts.lato(
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ),
        ListTile(
          title: Text(
            'Get Chat Privilege',
            style: GoogleFonts.lato(
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
          onTap: () async => {
            debugPrint(
                "Chat Privilege = ${await zoom.chatHelper.getChatPrivilege()}"),
            Navigator.of(context).pop(),
          },
        ),
        ListTile(
          title: Text(
            'Get Session Dial-in Number infos',
            style: GoogleFonts.lato(
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
          onTap: () async => {
            debugPrint(
                "session number = ${await zoom.session.getSessionNumber()}"),
            Navigator.of(context).pop(),
          },
        ),
        ListTile(
          title: Text(
            'Switch Camera',
            style: GoogleFonts.lato(
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
          onTap: () async => {
            await zoom.videoHelper.switchCamera(null),
            Navigator.of(context).pop(),
          },
        ),
        ListTile(
          title: Text(
            '${isMicOriginalOn.value ? 'Disable' : 'Enable'} Original Sound',
            style: GoogleFonts.lato(
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
          onTap: () async => {
            debugPrint("${isMicOriginalOn.value}"),
            await zoom.audioSettingHelper
                .enableMicOriginalInput(!isMicOriginalOn.value),
            isMicOriginalOn.value =
            await zoom.audioSettingHelper.isMicOriginalInputEnable(),
            debugPrint(
                "Original sound ${isMicOriginalOn.value ? 'Enabled' : 'Disabled'}"),
            Navigator.of(context).pop(),
          },
        )
      ];

      if (shareStatus == ShareStatus.Pause) {
        options.add(
          ListTile(
            title: Text(
              'Resume share screen',
              style: GoogleFonts.lato(
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
              ),
            ),
            onTap: () async => {
              debugPrint(
                  'resume result = ${await zoom.shareHelper.resumeShare()}'),
              Navigator.of(context).pop(),
            },
          ),
        );
      } else if (shareStatus == ShareStatus.Start) {
        options.add(
          ListTile(
            title: Text(
              'Pause share screen',
              style: GoogleFonts.lato(
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
              ),
            ),
            onTap: () async => {
              debugPrint(
                  'pause result = ${await zoom.shareHelper.pauseShare()}'),
              Navigator.of(context).pop(),
            },
          ),
        );
      }

      if (supportVB) {
        options.add(
          ListTile(
            title: Text(
              'Add Virtual Background',
              style: GoogleFonts.lato(
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
              ),
            ),
            onTap: () async => {
              selectVirtualBackgroundItem(),
              Navigator.of(context).pop(),
            },
          ),
        );
      }

      if (canCallOutToCRC) {
        options.add(ListTile(
          title: Text(
            'Call-out to CRC devices',
            style: GoogleFonts.lato(
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
          onTap: () async => {
            debugPrint(
                'CRC result = ${await zoom.CRCHelper.callCRCDevice("bjn.vc", ZoomVideoSdkCRCProtocolType.SIP)}'),
            Navigator.of(context).pop(),
          },
        ));
        options.add(ListTile(
          title: Text(
            'Cancel call-out to CRC devices',
            style: GoogleFonts.lato(
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
          onTap: () async => {
            debugPrint(
                'cancel result= ${await zoom.CRCHelper.cancelCallCRCDevice()}'),
            Navigator.of(context).pop(),
          },
        ));
      }

      if (canSwitchSpeaker) {
        options.add(ListTile(
          title: Text(
            'Turn ${isSpeakerOn.value ? 'off' : 'on'} Speaker',
            style: GoogleFonts.lato(
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
          onTap: () async => {
            await zoom.audioHelper.setSpeaker(!isSpeakerOn.value),
            isSpeakerOn.value = await zoom.audioHelper.getSpeakerStatus(),
            debugPrint('Turned ${isSpeakerOn.value ? 'on' : 'off'} Speaker'),
            Navigator.of(context).pop(),
          },
        ));
      }

      if (isHost) {
        options.add(ListTile(
            title: Text(
              '${isShareLocked ? 'Unlock' : 'Lock'} Share',
              style: GoogleFonts.lato(
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
              ),
            ),
            onTap: () async => {
              debugPrint(
                  "isShareLocked = ${await zoom.shareHelper.lockShare(!isShareLocked)}"),
              Navigator.of(context).pop(),
            }));
        options.add(ListTile(
          title: Text(
            'Change Name',
            style: GoogleFonts.lato(
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
          onTap: () => {
            isRenameModalVisible.value = true,
            Navigator.of(context).pop(),
          },
        ));
      }

      if (canStartLiveTranscription) {
        options.add(ListTile(
          title: Text(
            "${startLiveTranscription ? 'Stop' : 'Start'} Live Transcription",
            style: GoogleFonts.lato(
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
          onTap: () async => {
            if (startLiveTranscription)
              {
                debugPrint(
                    'stopLiveTranscription= ${await zoom.liveTranscriptionHelper.stopLiveTranscription()}'),
              }
            else
              {
                debugPrint(
                    'startLiveTranscription= ${await zoom.liveTranscriptionHelper.startLiveTranscription()}'),
              },
            Navigator.of(context).pop(),
          },
        ));
        options.add(ListTile(
            title: Text(
              '${isReceiveSpokenLanguageContentEnabled.value ? 'Disable' : 'Enable'} receiving original caption',
              style: GoogleFonts.lato(
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
              ),
            ),
            onTap: () async => {
              await zoom.liveTranscriptionHelper
                  .enableReceiveSpokenLanguageContent(
                  !isReceiveSpokenLanguageContentEnabled.value),
              isReceiveSpokenLanguageContentEnabled.value = await zoom
                  .liveTranscriptionHelper
                  .isReceiveSpokenLanguageContentEnabled(),
              debugPrint(
                  "isReceiveSpokenLanguageContentEnabled = ${isReceiveSpokenLanguageContentEnabled.value}"),
              Navigator.of(context).pop(),
            }));
      }

      if (canStartRecording) {
        options.add(ListTile(
            title: Text(
              '${isRecordingStarted.value ? 'Stop' : 'Start'} Recording',
              style: GoogleFonts.lato(
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
              ),
            ),
            onTap: () async => {
              if (!isRecordingStarted.value)
                {
                  debugPrint(
                      'isRecordingStarted = ${await zoom.recordingHelper.startCloudRecording()}'),
                }
              else
                {
                  debugPrint(
                      'isRecordingStarted = ${await zoom.recordingHelper.stopCloudRecording()}'),
                },
              Navigator.of(context).pop(),
            }));
      }

      if (Platform.isAndroid) {
        bool isFlashlightSupported =
        await zoom.videoHelper.isSupportFlashlight();
        bool isFlashlightOn = await zoom.videoHelper.isFlashlightOn();
        if (isFlashlightSupported) {
          options.add(ListTile(
              title: Text(
                '${isFlashlightOn ? 'Turn Off' : 'Turn On'} Flashlight',
                style: GoogleFonts.lato(
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: Colors.black,
                  ),
                ),
              ),
              onTap: () async => {
                if (!isFlashlightOn)
                  {
                    await zoom.videoHelper.turnOnOrOffFlashlight(true),
                  }
                else
                  {
                    await zoom.videoHelper.turnOnOrOffFlashlight(false),
                  },
                Navigator.of(context).pop(),
              }));
        }
      }

      if (Platform.isIOS) {
        options.add(ListTile(
            title: Text(
              '${isPiPView.value ? 'Disable' : 'Enable'} picture in picture view',
              style: GoogleFonts.lato(
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
              ),
            ),
            onTap: () async => {
              isPiPView.value = !isPiPView.value,
              Navigator.of(context).pop(),
            }));
      }

      if (isVideoOn.value) {
        options.add(ListTile(
            title: Text(
              'Mirror the video',
              style: GoogleFonts.lato(
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
              ),
            ),
            onTap: () async => {
              await zoom.videoHelper.mirrorMyVideo(!isVideoMirrored.value),
              isVideoMirrored.value =
              await zoom.videoHelper.isMyVideoMirrored(),
              Navigator.of(context).pop(),
            }));
        options.add(ListTile(
            title: Text(
              '${isOriginalAspectRatio.value ? 'Enable' : 'Disable'} original aspect ratio',
              style: GoogleFonts.lato(
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
              ),
            ),
            onTap: () async => {
              await zoom.videoHelper
                  .enableOriginalAspectRatio(!isOriginalAspectRatio.value),
              isOriginalAspectRatio.value =
              await zoom.videoHelper.isOriginalAspectRatioEnabled(),
              debugPrint(
                  "isOriginalAspectRatio= ${isOriginalAspectRatio.value}"),
              Navigator.of(context).pop(),
            }));
      }

      showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              elevation: 0.0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 40),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: SizedBox(
                height: 500,
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

    void leaveConsultation() async {
      await zoom.leaveSession(false);
    }

    Widget fullScreenView;
    Widget smallView;

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
              statusText.value,
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ));
    }
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
              onTap: () async {},
              onDoubleTap: () async {},
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
