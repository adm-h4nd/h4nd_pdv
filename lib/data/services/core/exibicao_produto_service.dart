import '../../../core/network/api_client.dart';
import '../../models/core/api_response.dart';
import '../../models/core/exibicao_produto_list_item.dart';
import '../../models/core/produto_exibicao_basico.dart';

/// Serviço para gerenciamento de Exibição de Produtos
class ExibicaoProdutoService {
  final ApiClient _apiClient;

  ExibicaoProdutoService({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// Obtém categorias raiz (sem categoria pai)
  Future<ApiResponse<List<ExibicaoProdutoListItemDto>>> getCategoriasRaiz() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/exibicoes-produto/raiz');
      
      return ApiResponse<List<ExibicaoProdutoListItemDto>>.fromJson(
        response.data!,
        (json) {
          if (json == null) return <ExibicaoProdutoListItemDto>[];
          if (json is List) {
            return json
                .map((item) => ExibicaoProdutoListItemDto.fromJson(item as Map<String, dynamic>))
                .toList();
          }
          return <ExibicaoProdutoListItemDto>[];
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Obtém categorias filhas de uma categoria pai
  Future<ApiResponse<List<ExibicaoProdutoListItemDto>>> getCategoriasFilhas(String categoriaPaiId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/exibicoes-produto/por-pai/$categoriaPaiId');
      
      return ApiResponse<List<ExibicaoProdutoListItemDto>>.fromJson(
        response.data!,
        (json) {
          if (json == null) return <ExibicaoProdutoListItemDto>[];
          if (json is List) {
            return json
                .map((item) => ExibicaoProdutoListItemDto.fromJson(item as Map<String, dynamic>))
                .toList();
          }
          return <ExibicaoProdutoListItemDto>[];
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Obtém produtos vinculados a uma categoria
  Future<ApiResponse<List<ProdutoExibicaoBasicoDto>>> getProdutosPorCategoria(String categoriaId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/exibicoes-produto/$categoriaId');
      
      return ApiResponse<List<ProdutoExibicaoBasicoDto>>.fromJson(
        response.data!,
        (json) {
          if (json == null) return <ProdutoExibicaoBasicoDto>[];
          final data = json as Map<String, dynamic>;
          final produtos = data['produtos'] as List?;
          if (produtos == null) return <ProdutoExibicaoBasicoDto>[];
          
          return produtos
              .map((item) => ProdutoExibicaoBasicoDto.fromJson(item as Map<String, dynamic>))
              .toList();
        },
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

