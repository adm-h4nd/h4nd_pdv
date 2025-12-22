import '../../base/crud_service.dart';
import '../../../models/modules/restaurante/comanda_list_item.dart';
import '../../../models/modules/restaurante/comanda_filter.dart';
import '../../../../core/network/api_client.dart';
import '../../../models/core/api_response.dart';
import '../../../models/core/paginated_response.dart';
import '../../../../core/network/endpoints.dart';

/// Serviço para gerenciamento de comandas
class ComandaService extends CrudService<ComandaListItemDto, ComandaListItemDto> {
  ComandaService({required ApiClient apiClient})
      : super(
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
  Future<ApiResponse<PaginatedResponseDto<ComandaListItemDto>>> searchComandas({
    required int page,
    required int pageSize,
    ComandaFilterDto? filter,
  }) async {
    final filterMap = (filter ?? ComandaFilterDto()).toJson();
    return search<Map<String, dynamic>>(
      page: page,
      pageSize: pageSize,
      filter: filterMap,
    );
  }

  /// Busca uma comanda completa por ID (inclui informações de sessão)
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
    } catch (e) {
      return ApiResponse<ComandaListItemDto>.error(
        message: 'Erro ao buscar comanda: ${e.toString()}',
      );
    }
  }

  /// Busca comanda por código de barras
  Future<ApiResponse<ComandaListItemDto>> getByCodigoBarras(String codigo) async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.comandaPorCodigoBarras(codigo),
      );
      return ApiResponse<ComandaListItemDto>.fromJson(
        response.data!,
        (json) => fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      rethrow;
    }
  }

}
