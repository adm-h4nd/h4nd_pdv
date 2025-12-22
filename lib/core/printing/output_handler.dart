import 'print_data.dart';
import 'print_config.dart';

/// Interface para handlers de saída de impressão
abstract class OutputHandler {
  /// Estratégia de saída
  OutputStrategy get strategy;
  
  /// Se o handler está disponível
  bool get isAvailable;
  
  /// Processa a saída
  Future<OutputResult> handle(
    PrintData data,
    DocumentType documentType,
  );
}

/// Resultado de uma saída
class OutputResult {
  final bool success;
  final String? errorMessage;
  final String? filePath; // Para PDF/Share
  final bool canShare;
  
  OutputResult({
    required this.success,
    this.errorMessage,
    this.filePath,
    this.canShare = false,
  });
}

