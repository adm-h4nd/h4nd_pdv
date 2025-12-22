import '../../base/crud_service.dart';
import '../../../models/modules/restaurante/mesa_list_item.dart';
import '../../../models/modules/restaurante/mesa_filter.dart';
import '../../../../core/network/api_client.dart';
import '../../../models/core/api_response.dart';
import '../../../models/core/paginated_response.dart';

/// Serviço para gerenciamento de mesas
class MesaService extends CrudService<MesaListItemDto, MesaListItemDto> {
  MesaService({required ApiClient apiClient})
      : super(
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
  Future<ApiResponse<PaginatedResponseDto<MesaListItemDto>>> searchMesas({
    required int page,
    required int pageSize,
    MesaFilterDto? filter,
  }) async {
    // Converte o filtro para Map antes de passar para search
    final filterMap = (filter ?? MesaFilterDto()).toJson();
    return search<Map<String, dynamic>>(
      page: page,
      pageSize: pageSize,
      filter: filterMap,
    );
  }

  /// Busca uma mesa completa por ID (inclui informações de sessão)
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
    } catch (e) {
      return ApiResponse<MesaListItemDto>.error(
        message: 'Erro ao buscar mesa: ${e.toString()}',
      );
    }
  }

}

