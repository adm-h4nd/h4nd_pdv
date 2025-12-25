import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../base/crud_service.dart';
import '../../../models/modules/restaurante/comanda_list_item.dart';
import '../../../models/modules/restaurante/comanda_filter.dart';
import '../../../../core/network/api_client.dart';
import '../../../models/core/api_response.dart';
import '../../../models/core/paginated_response.dart';
import '../../../../core/network/endpoints.dart';
import '../../../repositories/comanda_local_repository.dart';

/// Serviço para gerenciamento de comandas
/// Suporta modo offline usando dados locais quando não há conexão
class ComandaService extends CrudService<ComandaListItemDto, ComandaListItemDto> {
  final ComandaLocalRepository? _comandaLocalRepo;

  ComandaService({
    required ApiClient apiClient,
    ComandaLocalRepository? comandaLocalRepo,
  })  : _comandaLocalRepo = comandaLocalRepo,
        super(
          apiClient: apiClient,
          resourcePath: 'comandas',
        );

  @override
  ComandaListItemDto fromJson(Map<String, dynamic> json) {
    return ComandaListItemDto.fromJson(json);
  }

  @override
  ComandaListItemDto fromListJson(Map<String, dynamic> json) {
    return ComandaListItemDto.fromJson(json);
  }

  /// Busca comandas com filtros
  /// Se offline, retorna comandas do cache local com status padrão "Livre"
  Future<ApiResponse<PaginatedResponseDto<ComandaListItemDto>>> searchComandas({
    required int page,
    required int pageSize,
    ComandaFilterDto? filter,
  }) async {
    try {
      // Tenta buscar da API primeiro
      final filterMap = (filter ?? ComandaFilterDto()).toJson();
      return await search<Map<String, dynamic>>(
        page: page,
        pageSize: pageSize,
        filter: filterMap,
      );
    } on DioException catch (e) {
      debugPrint('⚠️ Erro de conexão ao buscar comandas: ${e.type} - ${e.message}');
      // Se for erro de conexão e tiver repositório local, usa dados locais
      if (_isNetworkError(e) && _comandaLocalRepo != null) {
        debugPrint('📱 Usando dados locais de comandas (modo offline)');
        return _getComandasFromLocal(page: page, pageSize: pageSize, filter: filter);
      }
      // Se não for erro de rede ou não tiver repositório local, re-lança o erro
      debugPrint('❌ Erro não é de rede ou repositório local não disponível');
      rethrow;
    } catch (e) {
      debugPrint('⚠️ Erro genérico ao buscar comandas: $e');
      // Outros erros: se tiver repositório local, tenta usar dados locais
      if (_comandaLocalRepo != null) {
        debugPrint('📱 Tentando usar dados locais de comandas (fallback)');
        return _getComandasFromLocal(page: page, pageSize: pageSize, filter: filter);
      }
      rethrow;
    }
  }

  /// Busca comandas do cache local (modo offline)
  Future<ApiResponse<PaginatedResponseDto<ComandaListItemDto>>> _getComandasFromLocal({
    required int page,
    required int pageSize,
    ComandaFilterDto? filter,
  }) async {
    try {
      await _comandaLocalRepo!.init();
      var comandas = _comandaLocalRepo!.getAllAsListItemDto();

      // Aplicar filtros básicos se houver
      if (filter != null) {
        if (filter.search != null && filter.search!.isNotEmpty) {
          final searchLower = filter.search!.toLowerCase();
          comandas = comandas.where((c) =>
            c.numero.toLowerCase().contains(searchLower) ||
            (c.descricao != null && c.descricao!.toLowerCase().contains(searchLower)) ||
            (c.codigoBarras != null && c.codigoBarras!.toLowerCase().contains(searchLower))
          ).toList();
        }

        if (filter.ativa != null) {
          comandas = comandas.where((c) => c.ativa == filter.ativa).toList();
        }
      }

      // Paginação
      final total = comandas.length;
      final skip = (page - 1) * pageSize;
      final paginatedComandas = comandas.skip(skip).take(pageSize).toList();

      final totalPages = (total / pageSize).ceil();
      return ApiResponse<PaginatedResponseDto<ComandaListItemDto>>.success(
        data: PaginatedResponseDto<ComandaListItemDto>(
          list: paginatedComandas,
          pagination: PaginationInfoDto(
            page: page,
            pageSize: pageSize,
            totalItems: total,
            totalPages: totalPages,
            hasNext: page < totalPages,
            hasPrevious: page > 1,
          ),
        ),
        message: 'Comandas carregadas do cache local (modo offline)',
      );
    } catch (e) {
      return ApiResponse<PaginatedResponseDto<ComandaListItemDto>>.error(
        message: 'Erro ao buscar comandas do cache local: ${e.toString()}',
      );
    }
  }

  /// Verifica se é erro de rede/conexão
  bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown;
  }

  /// Busca uma comanda completa por ID (inclui informações de sessão)
  /// Se offline, busca do cache local
  Future<ApiResponse<ComandaListItemDto>> getComandaById(String comandaId) async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.comandaById(comandaId),
      );

      if (response.data == null) {
        return ApiResponse<ComandaListItemDto>.error(
          message: 'Comanda não encontrada',
        );
      }

      final data = response.data!;
      final comandaData = data['data'] as Map<String, dynamic>?;
      
      if (comandaData == null) {
        return ApiResponse<ComandaListItemDto>.error(
          message: data['message'] as String? ?? 'Comanda não encontrada',
        );
      }

      final comanda = fromJson(comandaData);
      return ApiResponse<ComandaListItemDto>.success(
        data: comanda,
        message: data['message'] as String? ?? 'Comanda encontrada',
      );
    } on DioException catch (e) {
      // Se for erro de conexão e tiver repositório local, busca do cache
      if (_isNetworkError(e) && _comandaLocalRepo != null) {
        return _getComandaByIdFromLocal(comandaId);
      }
      return ApiResponse<ComandaListItemDto>.error(
        message: 'Erro ao buscar comanda: ${e.toString()}',
      );
    } catch (e) {
      // Outros erros: se tiver repositório local, tenta buscar do cache
      if (_comandaLocalRepo != null) {
        return _getComandaByIdFromLocal(comandaId);
      }
      return ApiResponse<ComandaListItemDto>.error(
        message: 'Erro ao buscar comanda: ${e.toString()}',
      );
    }
  }

  /// Busca comanda do cache local por ID (modo offline)
  Future<ApiResponse<ComandaListItemDto>> _getComandaByIdFromLocal(String comandaId) async {
    try {
      await _comandaLocalRepo!.init();
      final comandaLocal = _comandaLocalRepo!.getById(comandaId);
      
      if (comandaLocal == null) {
        return ApiResponse<ComandaListItemDto>.error(
          message: 'Comanda não encontrada no cache local',
        );
      }

      final comanda = _comandaLocalRepo!.toListItemDto(comandaLocal);
      return ApiResponse<ComandaListItemDto>.success(
        data: comanda,
        message: 'Comanda encontrada no cache local (modo offline)',
      );
    } catch (e) {
      return ApiResponse<ComandaListItemDto>.error(
        message: 'Erro ao buscar comanda do cache local: ${e.toString()}',
      );
    }
  }

  /// Busca comanda por código de barras
  /// Se offline, busca do cache local
  Future<ApiResponse<ComandaListItemDto>> getByCodigoBarras(String codigo) async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.comandaPorCodigoBarras(codigo),
      );
      return ApiResponse<ComandaListItemDto>.fromJson(
        response.data!,
        (json) => fromJson(json as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      // Se for erro de conexão e tiver repositório local, busca do cache
      if (_isNetworkError(e) && _comandaLocalRepo != null) {
        return _getComandaByCodigoBarrasFromLocal(codigo);
      }
      rethrow;
    } catch (e) {
      // Outros erros: se tiver repositório local, tenta buscar do cache
      if (_comandaLocalRepo != null) {
        return _getComandaByCodigoBarrasFromLocal(codigo);
      }
      rethrow;
    }
  }

  /// Busca comanda do cache local por código de barras (modo offline)
  Future<ApiResponse<ComandaListItemDto>> _getComandaByCodigoBarrasFromLocal(String codigo) async {
    try {
      await _comandaLocalRepo!.init();
      final comandaLocal = _comandaLocalRepo!.getByCodigoBarras(codigo);
      
      if (comandaLocal == null) {
        return ApiResponse<ComandaListItemDto>.error(
          message: 'Comanda não encontrada no cache local',
        );
      }

      final comanda = _comandaLocalRepo!.toListItemDto(comandaLocal);
      return ApiResponse<ComandaListItemDto>.success(
        data: comanda,
        message: 'Comanda encontrada no cache local (modo offline)',
      );
    } catch (e) {
      return ApiResponse<ComandaListItemDto>.error(
        message: 'Erro ao buscar comanda do cache local: ${e.toString()}',
      );
    }
  }

}
