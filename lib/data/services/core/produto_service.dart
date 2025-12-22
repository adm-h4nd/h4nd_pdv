import 'package:flutter/foundation.dart';
import '../base/crud_service.dart';
import '../../models/core/produto_list_item.dart';
import '../../models/core/produto_filter.dart';
import '../../models/core/produto_completo.dart';
import 'atributo_service.dart';
import '../../../core/network/api_client.dart';
import '../../models/core/api_response.dart';
import '../../models/core/paginated_response.dart';

/// Serviço para gerenciamento de produtos
class ProdutoService extends CrudService<ProdutoListItemDto, ProdutoListItemDto> {
  final AtributoService _atributoService;

  ProdutoService({
    required ApiClient apiClient,
    AtributoService? atributoService,
  })  : _atributoService = atributoService ?? AtributoService(apiClient: apiClient),
        super(
          apiClient: apiClient,
          resourcePath: 'produto',
        );

  @override
  ProdutoListItemDto fromJson(Map<String, dynamic> json) {
    return ProdutoListItemDto.fromJson(json);
  }

  @override
  ProdutoListItemDto fromListJson(Map<String, dynamic> json) {
    return ProdutoListItemDto.fromJson(json);
  }

  /// Busca produtos com filtros
  Future<ApiResponse<PaginatedResponseDto<ProdutoListItemDto>>> searchProdutos({
    required int page,
    required int pageSize,
    ProdutoFilterDto? filter,
  }) async {
    // Converte o filtro para Map antes de passar para search
    final filterMap = (filter ?? ProdutoFilterDto()).toJson();
    return search<Map<String, dynamic>>(
      page: page,
      pageSize: pageSize,
      filter: filterMap,
    );
  }

  /// Obtém produto completo com atributos e variações
  /// Carrega também os valores de cada atributo
  /// Usa o mesmo endpoint do getById, mas retorna ProdutoCompletoDto
  Future<ApiResponse<ProdutoCompletoDto>> getProdutoCompleto(String produtoId) async {
    try {
      // Usa o mesmo endpoint que getById, mas com conversão para ProdutoCompletoDto
      final response = await apiClient.get<Map<String, dynamic>>('/produto/$produtoId');
      
      final produtoResponse = ApiResponse<ProdutoCompletoDto>.fromJson(
        response.data!,
        (json) => ProdutoCompletoDto.fromJson(json as Map<String, dynamic>),
      );

      // Se o produto tem atributos, carregar valores de cada atributo separadamente
      // (pois o backend não retorna valores no ProdutoAtributoDto)
      if (produtoResponse.success && produtoResponse.data != null) {
        debugPrint('Carregando valores de ${produtoResponse.data!.atributos.length} atributos');
        for (var atributo in produtoResponse.data!.atributos) {
          try {
            debugPrint('Carregando valores do atributo ${atributo.nome} (ID: ${atributo.atributoId})');
            final atributoCompleto = await _atributoService.getAtributoCompleto(atributo.atributoId);
            if (atributoCompleto.success && atributoCompleto.data != null) {
              atributo.valores = atributoCompleto.data!.valores;
              debugPrint('✓ Valores carregados: ${atributo.valores?.length ?? 0} valores para ${atributo.nome}');
            } else {
              debugPrint('✗ Falha ao carregar valores do atributo ${atributo.nome}: ${atributoCompleto.message}');
            }
          } catch (e, stackTrace) {
            // Se falhar ao carregar valores, continua sem eles
            debugPrint('✗ Erro ao carregar valores do atributo ${atributo.nome} (${atributo.id}): $e');
            debugPrint('Stack trace: $stackTrace');
          }
        }
        debugPrint('Concluído carregamento de valores dos atributos');
      }

      return produtoResponse;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Filtra variações disponíveis baseado nos valores de atributos selecionados
  /// Retorna apenas variações que contêm todos os valores selecionados
  Future<ApiResponse<List<ProdutoVariacaoDto>>> filtrarVariacoes({
    required String produtoId,
    required List<String> valorIds,
  }) async {
    try {
      // Buscar produto completo com todas as variações
      final produtoCompleto = await getProdutoCompleto(produtoId);
      if (!produtoCompleto.success || produtoCompleto.data == null) {
        return ApiResponse<List<ProdutoVariacaoDto>>.error(
          message: produtoCompleto.message ?? 'Erro ao buscar produto',
        );
      }

      // Filtrar variações que contêm todos os valores selecionados
      final variacoesFiltradas = produtoCompleto.data!.variacoes.where((variacao) {
        final variacaoValorIds = variacao.valores.map((v) => v.atributoValorId).toList();
        // Verifica se todos os valores selecionados estão na variação
        return valorIds.every((valorId) => variacaoValorIds.contains(valorId));
      }).toList();

      return ApiResponse<List<ProdutoVariacaoDto>>.success(
        data: variacoesFiltradas,
        message: 'Variações filtradas com sucesso',
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    if (error is Exception) return error;
    return Exception(error.toString());
  }
}
