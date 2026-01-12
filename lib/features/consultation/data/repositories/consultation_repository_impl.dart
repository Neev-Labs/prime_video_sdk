import '../../domain/repositories/consultation_repository.dart';
import '../datasources/consultation_remote_data_source.dart';
import '../../../../model/consultation_response.dart';
import '../../../../model/consultation_check_response.dart';

class ConsultationRepositoryImpl implements ConsultationRepository {
  final ConsultationRemoteDataSource remoteDataSource;

  ConsultationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<ConsultationCheckResponse?> checkConsultationStatus(String appointmentId, bool isProduction) async {
    return await remoteDataSource.consultationCheck(appointmentId, isProduction);
  }

  @override
  Future<ConsultationResponse?> joinConsultation(String userId, String appointmentId, bool isProduction) async {
    return await remoteDataSource.joinConsultation(userId, appointmentId, isProduction);
  }
}
