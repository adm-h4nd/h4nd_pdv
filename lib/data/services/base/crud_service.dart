import '../../models/core/api_response.dart';
import '../../models/core/paginated_response.dart';
import '../../../core/network/api_client.dart';

/// Serviço base CRUD para comunicação com API
/// Similar ao CrudService do Angular
/// 
/// Classes filhas devem implementar:
/// - TDto fromJson(Map<String, dynamic> json)
/// - TListDto fromListJson(Map<String, dynamic> json)
abstract class CrudService<TDto, TListDto> {
  final ApiClient _apiClient;
  final String resourcePath;

  CrudService({
    required ApiClient apiClient,
    required this.resourcePath,
  }) : _apiClient = apiClient;

  /// Getter para acesso ao ApiClient (para métodos customizados)
  ApiClient get apiClient => _apiClient;

  /// Lista itens com paginação
  Future<ApiResponse<PaginatedResponseDto<TListDto>>> list({
    required int page,
    required int pageSize,
    Map<String, dynamic>? extraParams,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        if (extraParams != null) ...extraParams,
      };

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/$resourcePath',
        queryParameters: queryParams,
      );

      return ApiResponse<PaginatedResponseDto<TListDto>>.fromJson(
        response.data!,
        (json) => PaginatedResponseDto<TListDto>.fromJson(
          json as Map<String, dynamic>,
          (itemJson) => fromListJson(itemJson as Map<String, dynamic>),
        ),
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Busca com filtros e paginação
  Future<ApiResponse<PaginatedResponseDto<TListDto>>> search<TFilter>({
    required int page,
    required int pageSize,
    required TFilter filter,
  }) async {
    try {
      // Converte o filtro para JSON se tiver método toJson
      dynamic filterJson = filter;
      if (filter is Map<String, dynamic>) {
        filterJson = filter;
      } else {
        // Tenta chamar toJson() se existir
        try {
          final dynamic filterObj = filter;
          if (filterObj.runtimeType.toString().contains('Dto')) {
            filterJson = (filterObj as dynamic).toJson();
          }
        } catch (_) {
          // Se não tiver toJson, usa o objeto diretamente
          filterJson = filter;
        }
      }

      final body = {
        'pagination': {
          'page': page,
          'pageSize': pageSize,
        },
        'filter': filterJson,
      };

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/$resourcePath/search',
        data: body,
      );

      return ApiResponse<PaginatedResponseDto<TListDto>>.fromJson(
        response.data!,
        (json) => PaginatedResponseDto<TListDto>.fromJson(
          json as Map<String, dynamic>,
          (itemJson) => fromListJson(itemJson as Map<String, dynamic>),
        ),
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Obtém item por ID
  Future<ApiResponse<TDto>> getById(String id) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/$resourcePath/$id',
      );

      return ApiResponse<TDto>.fromJson(
        response.data!,
        (json) => fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Cria novo item
  Future<ApiResponse<TDto>> create(Map<String, dynamic> payload) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/$resourcePath',
        data: payload,
      );

      return ApiResponse<TDto>.fromJson(
        response.data!,
        (json) => fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Atualiza item existente
  Future<ApiResponse<TDto>> update(String id, Map<String, dynamic> payload) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        '/$resourcePath/$id',
        data: payload,
      );

      return ApiResponse<TDto>.fromJson(
        response.data!,
        (json) => fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Deleta item
  Future<ApiResponse<bool>> delete(String id) async {
    try {
      final response = await _apiClient.delete<Map<String, dynamic>>(
        '/$resourcePath/$id',
      );

      return ApiResponse<bool>.fromJson(
        response.data!,
        (json) => json['data'] as bool,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Métodos abstratos para conversão JSON - devem ser implementados pelas classes filhas
  TDto fromJson(Map<String, dynamic> json);
  TListDto fromListJson(Map<String, dynamic> json);

  /// Trata erros
  dynamic _handleError(dynamic error) {
    // Pode ser sobrescrito por serviços específicos
    return error;
  }
}


