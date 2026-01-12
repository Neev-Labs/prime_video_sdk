import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../../data/datasources/consultation_remote_data_source.dart';
import '../../data/repositories/consultation_repository_impl.dart';
import '../../domain/repositories/consultation_repository.dart';
import '../../../../model/consultation_check_response.dart';
import '../../../../model/consultation_response.dart';

// HTTP Client Provider
final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

// DataSource Provider
final consultationRemoteDataSourceProvider = Provider<ConsultationRemoteDataSource>((ref) {
  return ConsultationRemoteDataSourceImpl(client: ref.read(httpClientProvider));
});

// Repository Provider
final consultationRepositoryProvider = Provider<ConsultationRepository>((ref) {
  return ConsultationRepositoryImpl(remoteDataSource: ref.read(consultationRemoteDataSourceProvider));
});

// State for the Notifier
class ConsultationState {
  final bool isLoading;
  final String? errorMessage; // PSDK_E_ codes
  final ConsultationCheckResponse? checkResponse;
  final ConsultationResponse? consultationResponse;
  final String? status; // 'WAITING', 'JOINED', etc.

  ConsultationState({
    this.isLoading = false,
    this.errorMessage,
    this.checkResponse,
    this.consultationResponse,
    this.status,
  });

  ConsultationState copyWith({
    bool? isLoading,
    String? errorMessage,
    ConsultationCheckResponse? checkResponse,
    ConsultationResponse? consultationResponse,
    String? status,
  }) {
    return ConsultationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      checkResponse: checkResponse ?? this.checkResponse,
      consultationResponse: consultationResponse ?? this.consultationResponse,
      status: status ?? this.status,
    );
  }
}

// ViewModel (Notifier)
class ConsultationNotifier extends StateNotifier<ConsultationState> {
  final ConsultationRepository repository;

  ConsultationNotifier({required this.repository}) : super(ConsultationState());

  Future<void> joinProcess(String appointmentId, bool isProduction) async {
    // Permission Check
    var cameraStatus = await Permission.camera.status;
    var microphoneStatus = await Permission.microphone.status;

    if (!cameraStatus.isGranted || !microphoneStatus.isGranted) {
       // Ideally trigger UI to ask, but logic says return error if not granted
       state = state.copyWith(errorMessage: 'PSDK_E_3');
       return;
    }

    try {
      // 1. Check Status
      final checkResp = await repository.checkConsultationStatus(appointmentId, isProduction);
      if (checkResp == null || checkResp.data == null) {
        state = state.copyWith(errorMessage: 'PSDK_E_2');
        return;
      }
      state = state.copyWith(checkResponse: checkResp); 

      if (checkResp.data?.appointmentStatus != 'ACTIVE') {
        state = state.copyWith(status: 'WAITING');
        return;
      }

      final userId = checkResp.data?.patientId;
      if (userId == null) {
        state = state.copyWith(errorMessage: 'PSDK_E_2');
        return;
      }

      // 2. Call Consultation
      final consultResp = await repository.joinConsultation(userId, appointmentId, isProduction);
      if (consultResp == null) {
         state = state.copyWith(errorMessage: 'PSDK_E_500'); 
         return;
      }

      if (consultResp.data?.doctorScreenstatus == 'In Consultation Screen') {
         state = state.copyWith(
           consultationResponse: consultResp,
           status: 'JOINED',
           errorMessage: null, 
         );
      } else {
         state = state.copyWith(status: 'WAITING');
      }

    } catch (e) {
      state = state.copyWith(errorMessage: 'PSDK_E_500'); 
    }
  }
  
  void resetStatus() {
     state = state.copyWith(status: null, errorMessage: null);
  }
}

final consultationProvider = StateNotifierProvider<ConsultationNotifier, ConsultationState>((ref) {
  return ConsultationNotifier(repository: ref.read(consultationRepositoryProvider));
});
