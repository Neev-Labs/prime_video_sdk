import '../../../../model/consultation_response.dart';
import '../../../../model/consultation_check_response.dart';

abstract class ConsultationRepository {
  Future<ConsultationCheckResponse?> checkConsultationStatus(String appointmentId, bool isProduction);
  Future<ConsultationResponse?> joinConsultation(String userId, String appointmentId, bool isProduction);
}
