import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/config/connection_config_service.dart';

/// Resultado da sincronização da API local
class LocalApiSyncResult {
  final bool success;
  final String? error;
  final String? message;
  final int totalTables;
  final int successfulTables;
  final int failedTables;
  final int totalRecordsProcessed;
  final int totalRecordsInserted;
  final int totalRecordsUpdated;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Duration? duration;

  LocalApiSyncResult({
    required this.success,
    this.error,
    this.message,
    this.totalTables = 0,
    this.successfulTables = 0,
    this.failedTables = 0,
    this.totalRecordsProcessed = 0,
    this.totalRecordsInserted = 0,
    this.totalRecordsUpdated = 0,
    this.startedAt,
    this.completedAt,
    this.duration,
  });

  factory LocalApiSyncResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      return LocalApiSyncResult(
        success: json['success'] as bool? ?? false,
        error: json['message'] as String?,
        message: json['message'] as String?,
      );
    }

    final startedAtStr = data['startedAt'] as String?;
    final completedAtStr = data['completedAt'] as String?;
    
    DateTime? startedAt;
    DateTime? completedAt;
    Duration? duration;

    if (startedAtStr != null) {
      try {
        startedAt = DateTime.parse(startedAtStr).toLocal();
      } catch (e) {
        debugPrint('Erro ao parsear startedAt: $e');
      }
    }

    if (completedAtStr != null) {
      try {
        completedAt = DateTime.parse(completedAtStr).toLocal();
        if (startedAt != null) {
          duration = completedAt.difference(startedAt);
        }
      } catch (e) {
        debugPrint('Erro ao parsear completedAt: $e');
      }
    }

    final tables = data['tables'] as List<dynamic>? ?? [];
    final successfulTables = tables.where((t) => t['success'] == true).length;
    final failedTables = tables.where((t) => t['success'] == false).length;

    int totalRecordsProcessed = 0;
    int totalRecordsInserted = 0;
    int totalRecordsUpdated = 0;

    for (final table in tables) {
      totalRecordsProcessed += (table['recordsProcessed'] as int?) ?? 0;
      totalRecordsInserted += (table['recordsInserted'] as int?) ?? 0;
      totalRecordsUpdated += (table['recordsUpdated'] as int?) ?? 0;
    }

    return LocalApiSyncResult(
      success: json['success'] as bool? ?? false,
      error: json['errors'] != null 
          ? (json['errors'] as List<dynamic>).join(', ')
          : data['errorMessage'] as String?,
      message: json['message'] as String?,
      totalTables: tables.length,
      successfulTables: successfulTables,
      failedTables: failedTables,
      totalRecordsProcessed: totalRecordsProcessed,
      totalRecordsInserted: totalRecordsInserted,
      totalRecordsUpdated: totalRecordsUpdated,
      startedAt: startedAt,
      completedAt: completedAt,
      duration: duration,
    );
  }
}

/// Serviço para sincronização com a API local
class LocalApiSyncService {
  final Dio _dio;

  LocalApiSyncService({required Dio dio}) : _dio = dio;

  /// Executa sincronização completa
  Future<LocalApiSyncResult> syncFull() async {
    try {
      final apiUrl = ConnectionConfigService.getApiUrl();
      if (apiUrl.isEmpty) {
        throw Exception('URL da API não configurada');
      }

      final url = '$apiUrl/sync/full';
      debugPrint('🔄 [LocalApiSyncService] Iniciando sincronização completa: $url');

      final response = await _dio.post(
        url,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final result = LocalApiSyncResult.fromJson(response.data);
        debugPrint('✅ [LocalApiSyncService] Sincronização completa finalizada: ${result.success}');
        return result;
      } else {
        throw Exception('Erro ao sincronizar: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [LocalApiSyncService] Erro na sincronização completa: $e');
      if (e is DioException) {
        final errorMessage = e.response?.data?['message'] as String? ?? 
                           e.response?.data?['errors']?.toString() ?? 
                           e.message ?? 'Erro desconhecido';
        return LocalApiSyncResult(
          success: false,
          error: errorMessage,
        );
      }
      return LocalApiSyncResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Executa sincronização incremental
  /// [lastSync] é opcional. Se não fornecido, a API usa a data salva no banco
  Future<LocalApiSyncResult> syncIncremental({DateTime? lastSync}) async {
    try {
      final apiUrl = ConnectionConfigService.getApiUrl();
      if (apiUrl.isEmpty) {
        throw Exception('URL da API não configurada');
      }

      final url = '$apiUrl/sync/incremental';
      debugPrint('🔄 [LocalApiSyncService] Iniciando sincronização incremental: $url');

      final requestData = <String, dynamic>{};
      if (lastSync != null) {
        requestData['lastSync'] = lastSync.toUtc().toIso8601String();
      }

      final response = await _dio.post(
        url,
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final result = LocalApiSyncResult.fromJson(response.data);
        debugPrint('✅ [LocalApiSyncService] Sincronização incremental finalizada: ${result.success}');
        return result;
      } else {
        throw Exception('Erro ao sincronizar: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [LocalApiSyncService] Erro na sincronização incremental: $e');
      if (e is DioException) {
        final errorMessage = e.response?.data?['message'] as String? ?? 
                           e.response?.data?['errors']?.toString() ?? 
                           e.message ?? 'Erro desconhecido';
        return LocalApiSyncResult(
          success: false,
          error: errorMessage,
        );
      }
      return LocalApiSyncResult(
        success: false,
        error: e.toString(),
      );
    }
  }
}

