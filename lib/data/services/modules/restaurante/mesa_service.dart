import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../base/crud_service.dart';
import '../../../models/modules/restaurante/mesa_list_item.dart';
import '../../../models/modules/restaurante/mesa_filter.dart';
import '../../../../core/network/api_client.dart';
import '../../../models/core/api_response.dart';
import '../../../models/core/paginated_response.dart';
import '../../../repositories/mesa_local_repository.dart';

/// Serviço para gerenciamento de mesas
/// Suporta modo offline usando dados locais quando não há conexão
class MesaService extends CrudService<MesaListItemDto, MesaListItemDto> {
  final MesaLocalRepository? _mesaLocalRepo;

  MesaService({
    required ApiClient apiClient,
    MesaLocalRepository? mesaLocalRepo,
  })  : _mesaLocalRepo = mesaLocalRepo,
        super(
          apiClient: apiClient,
          resourcePath: 'mesas',
        );

  @override
  MesaListItemDto fromJson(Map<String, dynamic> json) {
    return MesaListItemDto.fromJson(json);
  }

  @override
  MesaListItemDto fromListJson(Map<String, dynamic> json) {
    return MesaListItemDto.fromJson(json);
  }

  /// Busca mesas com filtros
  /// IMPORTANTE: Não usa fallback local - erros de conexão devem ser tratados pela UI
  /// A tela de mesas deve mostrar mensagem de offline quando não houver conexão
  Future<ApiResponse<PaginatedResponseDto<MesaListItemDto>>> searchMesas({
    required int page,
    required int pageSize,
    MesaFilterDto? filter,
  }) async {
    try {
      // Tenta buscar da API
      final filterMap = (filter ?? MesaFilterDto()).toJson();
      return await search<Map<String, dynamic>>(
        page: page,
        pageSize: pageSize,
        filter: filterMap,
      );
    } on DioException catch (e) {
      debugPrint('⚠️ Erro de conexão ao buscar mesas: ${e.type} - ${e.message}');
      // Não usa fallback local - deixa o erro propagar para a UI mostrar mensagem de offline
      rethrow;
    } catch (e) {
      debugPrint('⚠️ Erro genérico ao buscar mesas: $e');
      // Não usa fallback local - deixa o erro propagar
      rethrow;
    }
  }

  /// Busca mesas do cache local (modo offline)
  Future<ApiResponse<PaginatedResponseDto<MesaListItemDto>>> _getMesasFromLocal({
    required int page,
    required int pageSize,
    MesaFilterDto? filter,
  }) async {
    try {
      await _mesaLocalRepo!.init();
      var mesas = _mesaLocalRepo!.getAllAsListItemDto();

      // Aplicar filtros básicos se houver
      if (filter != null) {
        if (filter.searchTerm != null && filter.searchTerm!.isNotEmpty) {
          final searchLower = filter.searchTerm!.toLowerCase();
          mesas = mesas.where((m) =>
            m.numero.toLowerCase().contains(searchLower) ||
            (m.descricao != null && m.descricao!.toLowerCase().contains(searchLower))
          ).toList();
        }

        if (filter.ativa != null) {
          mesas = mesas.where((m) => m.ativa == filter.ativa).toList();
        }
      }

      // Paginação
      final total = mesas.length;
      final skip = (page - 1) * pageSize;
      final paginatedMesas = mesas.skip(skip).take(pageSize).toList();

      final totalPages = (total / pageSize).ceil();
      return ApiResponse<PaginatedResponseDto<MesaListItemDto>>.success(
        data: PaginatedResponseDto<MesaListItemDto>(
          list: paginatedMesas,
          pagination: PaginationInfoDto(
            page: page,
            pageSize: pageSize,
            totalItems: total,
            totalPages: totalPages,
            hasNext: page < totalPages,
            hasPrevious: page > 1,
          ),
        ),
        message: 'Mesas carregadas do cache local (modo offline)',
      );
    } catch (e) {
      return ApiResponse<PaginatedResponseDto<MesaListItemDto>>.error(
        message: 'Erro ao buscar mesas do cache local: ${e.toString()}',
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

  /// Busca uma mesa completa por ID (inclui informações de sessão)
  /// Se offline, busca do cache local
  Future<ApiResponse<MesaListItemDto>> getMesaById(String mesaId) async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/$resourcePath/$mesaId',
      );

      if (response.data == null) {
        return ApiResponse<MesaListItemDto>.error(
          message: 'Mesa não encontrada',
        );
      }

      final data = response.data!;
      final mesaData = data['data'] as Map<String, dynamic>?;
      
      if (mesaData == null) {
        return ApiResponse<MesaListItemDto>.error(
          message: data['message'] as String? ?? 'Mesa não encontrada',
        );
      }

      final mesa = MesaListItemDto.fromJson(mesaData);
      return ApiResponse<MesaListItemDto>.success(
        data: mesa,
        message: data['message'] as String? ?? 'Mesa encontrada',
      );
    } on DioException catch (e) {
      // Se for erro de conexão e tiver repositório local, busca do cache
      if (_isNetworkError(e) && _mesaLocalRepo != null) {
        return _getMesaByIdFromLocal(mesaId);
      }
      return ApiResponse<MesaListItemDto>.error(
        message: 'Erro ao buscar mesa: ${e.toString()}',
      );
    } catch (e) {
      // Outros erros: se tiver repositório local, tenta buscar do cache
      if (_mesaLocalRepo != null) {
        return _getMesaByIdFromLocal(mesaId);
      }
      return ApiResponse<MesaListItemDto>.error(
        message: 'Erro ao buscar mesa: ${e.toString()}',
      );
    }
  }

  /// Busca mesa do cache local por ID (modo offline)
  Future<ApiResponse<MesaListItemDto>> _getMesaByIdFromLocal(String mesaId) async {
    try {
      await _mesaLocalRepo!.init();
      final mesaLocal = _mesaLocalRepo!.getById(mesaId);
      
      if (mesaLocal == null) {
        return ApiResponse<MesaListItemDto>.error(
          message: 'Mesa não encontrada no cache local',
        );
      }

      final mesa = _mesaLocalRepo!.toListItemDto(mesaLocal);
      return ApiResponse<MesaListItemDto>.success(
        data: mesa,
        message: 'Mesa encontrada no cache local (modo offline)',
      );
    } catch (e) {
      return ApiResponse<MesaListItemDto>.error(
        message: 'Erro ao buscar mesa do cache local: ${e.toString()}',
      );
    }
  }

}

