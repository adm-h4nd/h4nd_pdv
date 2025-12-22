import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../presentation/providers/services_provider.dart';
import '../../../../presentation/providers/pedido_provider.dart';
import '../../../../data/repositories/exibicao_produto_local_repository.dart';
import '../../../../data/repositories/produto_local_repository.dart';
import '../../../../data/models/core/exibicao_produto_list_item.dart';
import '../../../../data/models/core/produto_exibicao_basico.dart';
import '../../../../data/models/core/produtos.dart';
import '../../../../data/models/local/exibicao_produto_local.dart';
import '../../../../data/models/local/produto_local.dart';
import '../../../../data/models/local/produto_variacao_local.dart';
import '../modals/selecionar_produto_modal.dart';

/// Componente de navegação em árvore para seleção de categorias e produtos
class CategoriaNavigationTree extends StatefulWidget {
  final Function(ProdutoExibicaoBasicoDto) onProdutoSelected;

  const CategoriaNavigationTree({
    super.key,
    required this.onProdutoSelected,
  });

  @override
  State<CategoriaNavigationTree> createState() => _CategoriaNavigationTreeState();
}

class _CategoriaNavigationTreeState extends State<CategoriaNavigationTree> {
  final List<ExibicaoProdutoListItemDto> _navigationStack = [];
  List<ExibicaoProdutoListItemDto> _currentCategories = [];
  List<ProdutoExibicaoBasicoDto>? _currentProducts;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Categorias raiz para tabs
  List<ExibicaoProdutoListItemDto> _categoriasRaiz = [];
  String? _categoriaRaizSelecionada; // ID da categoria raiz selecionada
  
  // Busca
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<ProdutoExibicaoBasicoDto> _searchResults = [];

  ExibicaoProdutoLocalRepository get _exibicaoRepo {
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    return servicesProvider.exibicaoLocalRepo;
  }

  ProdutoLocalRepository get _produtoRepo {
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    return servicesProvider.produtoLocalRepo;
  }

  @override
  void initState() {
    super.initState();
    _loadCategoriasRaiz();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      // Restaurar navegação normal se havia uma categoria selecionada
      if (_categoriaRaizSelecionada != null) {
        _selecionarCategoriaRaiz(_categoriaRaizSelecionada!);
      }
    } else {
      _performSearch(query);
    }
  }

  void _performSearch(String query) {
    setState(() {
      _isSearching = true;
    });

    try {
      final produtosEncontrados = _produtoRepo.buscarPorNome(query);
      
      // Converter para ProdutoExibicaoBasicoDto
      final resultados = produtosEncontrados.map((produto) {
        return _mapProdutoLocalToExibicaoBasico(produto, 0);
      }).toList();

      setState(() {
        _searchResults = resultados;
      });
    } catch (e) {
      debugPrint('Erro ao buscar produtos: $e');
      setState(() {
        _searchResults = [];
      });
    }
  }

  Future<void> _loadCategoriasRaiz() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _navigationStack.clear();
      _currentCategories = [];
      _currentProducts = null;
    });

    try {
      final categoriasLocais = _exibicaoRepo.buscarCategoriasRaiz();
      
      // Ordenar por quantidade de produtos (mais produtos primeiro)
      final categoriasOrdenadas = categoriasLocais.toList()
        ..sort((a, b) {
          final qtdA = _exibicaoRepo.contarProdutos(a.id);
          final qtdB = _exibicaoRepo.contarProdutos(b.id);
          return qtdB.compareTo(qtdA);
        });
      
      final categoriasDto = categoriasOrdenadas
          .map((c) => _mapExibicaoLocalToListItemDto(c))
          .toList();
      
      setState(() {
        _categoriasRaiz = categoriasDto;
        _currentCategories = categoriasDto;
        _isLoading = false;
        
        // Selecionar primeira categoria por padrão
        if (categoriasDto.isNotEmpty && _categoriaRaizSelecionada == null) {
          _categoriaRaizSelecionada = categoriasDto.first.id;
          _carregarConteudoCategoriaRaiz(categoriasDto.first.id);
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar categorias: ${e.toString()}';
        _isLoading = false;
      });
      debugPrint('Erro ao carregar categorias raiz: $e');
    }
  }

  void _selecionarCategoriaRaiz(String categoriaId) {
    setState(() {
      _categoriaRaizSelecionada = categoriaId;
      _navigationStack.clear();
      _currentProducts = null;
    });
    _carregarConteudoCategoriaRaiz(categoriaId);
  }

  Future<void> _carregarConteudoCategoriaRaiz(String categoriaId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final categoria = _exibicaoRepo.buscarPorId(categoriaId);
      if (categoria == null) {
        setState(() {
          _errorMessage = 'Categoria não encontrada';
          _isLoading = false;
        });
        return;
      }

      // Verificar se tem categorias filhas
      final categoriasFilhas = _exibicaoRepo.buscarCategoriasFilhas(categoriaId);
      
      if (categoriasFilhas.isNotEmpty) {
        // Tem subcategorias, mostrar elas
        setState(() {
          _currentCategories = categoriasFilhas
              .map((c) => _mapExibicaoLocalToListItemDto(c))
              .toList();
          _currentProducts = null;
          _isLoading = false;
        });
      } else {
        // Não tem subcategorias, carregar produtos
        final produtoIds = _exibicaoRepo.buscarProdutosPorCategoria(categoriaId);
        final produtosLocais = _produtoRepo.buscarPorIds(produtoIds);
        
        // Criar mapa de ordem dos produtos
        final ordemMap = <String, int>{};
        for (var i = 0; i < categoria.produtoIds.length; i++) {
          ordemMap[categoria.produtoIds[i]] = i;
        }
        
        final produtosDto = produtosLocais
            .map((p) => _mapProdutoLocalToExibicaoBasico(p, ordemMap[p.id] ?? 999))
            .toList()
          ..sort((a, b) => (a.ordem ?? 0).compareTo(b.ordem ?? 0));
        
        setState(() {
          _currentProducts = produtosDto;
          _currentCategories = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar categoria: ${e.toString()}';
        _isLoading = false;
      });
      debugPrint('Erro ao carregar conteúdo da categoria: $e');
    }
  }

  Future<void> _onCategoriaSelected(ExibicaoProdutoListItemDto categoria) async {
    await _abrirCategoria(categoria, pushToStack: true);
  }

  Future<void> _abrirCategoria(ExibicaoProdutoListItemDto categoria, {required bool pushToStack}) async {
    // Gerenciar stack conforme ação
    if (pushToStack) {
      setState(() {
        _navigationStack.add(categoria);
      });
    }

    // Preparar loading
    setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentProducts = null;
      });

      try {
      if (categoria.quantidadeCategoriasFilhas > 0) {
        final categoriasFilhas = _exibicaoRepo.buscarCategoriasFilhas(categoria.id);
        
        setState(() {
          _currentCategories = categoriasFilhas
              .map((c) => _mapExibicaoLocalToListItemDto(c))
              .toList();
          _currentProducts = null;
          _isLoading = false;
        });
    } else {
        final produtoIds = _exibicaoRepo.buscarProdutosPorCategoria(categoria.id);
        final produtosLocais = _produtoRepo.buscarPorIds(produtoIds);
        
        final ordemMap = <String, int>{};
        final categoriaLocal = _exibicaoRepo.buscarPorId(categoria.id);
        if (categoriaLocal != null) {
          for (var i = 0; i < categoriaLocal.produtoIds.length; i++) {
            ordemMap[categoriaLocal.produtoIds[i]] = i;
          }
        }
        
        setState(() {
          _currentCategories = [];
          _currentProducts = produtosLocais
              .map((p) => _mapProdutoLocalToExibicaoBasico(p, ordemMap[p.id] ?? 0))
              .toList()
            ..sort((a, b) => a.ordem.compareTo(b.ordem));
          _isLoading = false;
        });
      }
      } catch (e) {
        setState(() {
        _errorMessage = 'Erro ao carregar categoria: ${e.toString()}';
          _isLoading = false;
        });
      debugPrint('Erro ao carregar categoria: $e');
    }
  }

  void _onBackPressed() {
    if (_navigationStack.isEmpty) {
      _loadCategoriasRaiz();
      return;
    }

    setState(() {
      _navigationStack.removeLast();
      _currentProducts = null;
    });

    if (_navigationStack.isEmpty) {
      _loadCategoriasRaiz();
    } else {
      _abrirCategoria(_navigationStack.last, pushToStack: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Seção de navegação (search + tabs) num cartão clean e integrado
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: adaptive.isMobile ? 12 : 16, vertical: adaptive.isMobile ? 10 : 12),
          color: const Color(0xFFF5F6F7),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: adaptive.isMobile ? 12 : 14, vertical: adaptive.isMobile ? 12 : 14),
          decoration: BoxDecoration(
            color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
              ),
            ],
          ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Navegar catálogo',
                          style: GoogleFonts.inter(
                            fontSize: adaptive.isMobile ? 15 : 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          _isSearching ? 'Buscando...' : 'Categorias raiz e busca unificadas',
                          style: GoogleFonts.inter(
                            fontSize: adaptive.isMobile ? 12 : 12.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
            controller: _searchController,
            decoration: InputDecoration(
                    hintText: 'Buscar produtos ou categorias...',
              hintStyle: GoogleFonts.inter(
                      color: Colors.grey.shade500,
              ),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade600),
              suffixIcon: _isSearching
                  ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
          ),
                if (!_isSearching && _categoriasRaiz.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: adaptive.isMobile ? 84 : 96,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: adaptive.isMobile ? 4 : 6),
              itemCount: _categoriasRaiz.length,
              itemBuilder: (context, index) {
                final categoria = _categoriasRaiz[index];
                final isSelected = _categoriaRaizSelecionada == categoria.id;
                final imageUrl = categoria.imagemFileName != null && categoria.imagemFileName!.isNotEmpty
                    ? ImageUrlHelper.getThumbnailImageUrl(categoria.imagemFileName)
                    : null;
                final categoriaColor = categoria.cor != null && categoria.cor!.isNotEmpty
                    ? _parseColor(categoria.cor!)
                    : AppTheme.restauranteColor;
                
                return Padding(
                          padding: EdgeInsets.only(right: adaptive.isMobile ? 10 : 12),
                  child: _buildCategoriaTab(
                    categoria: categoria,
                    isSelected: isSelected,
                    imageUrl: imageUrl,
                    categoriaColor: categoriaColor,
                    onTap: () => _selecionarCategoriaRaiz(categoria.id),
                  ),
                );
              },
                    ),
                  ),
                ],
              ],
            ),
            ),
          ),
        
        // Breadcrumb de navegação (quando dentro de subcategorias)
        if (!_isSearching && _navigationStack.isNotEmpty)
          if (!_isSearching)
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: adaptive.isMobile ? 14 : 18,
                vertical: adaptive.isMobile ? 8 : 10,
            ),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F7),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _onBackPressed,
                  tooltip: 'Voltar',
                    color: AppTheme.textPrimary,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                          _buildCrumbText(
                            label: 'Início',
                            onTap: () {
                            setState(() {
                              _navigationStack.clear();
                              _currentProducts = null;
                            });
                            _loadCategoriasRaiz();
                          },
                            isActive: _navigationStack.isEmpty,
                            adaptive: adaptive,
                        ),
                        ..._navigationStack.map((categoria) {
                            final isLast = _navigationStack.last == categoria;
                          return Row(
                            children: [
                                Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade500),
                                _buildCrumbText(
                                  label: categoria.nome,
                                  onTap: () {
                                  final index = _navigationStack.indexOf(categoria);
                                  setState(() {
                                    _navigationStack.removeRange(
                                      index + 1,
                                      _navigationStack.length,
                                    );
                                    _currentProducts = null;
                                  });

                                    if (_navigationStack.isEmpty) {
                                    _loadCategoriasRaiz();
                                  } else {
                                      _abrirCategoria(_navigationStack.last, pushToStack: false);
                                  }
                                },
                                  isActive: isLast,
                                  adaptive: adaptive,
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Conteúdo: busca ou navegação normal
        Expanded(
          child: _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppTheme.errorColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadCategoriasRaiz,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : _isSearching
                  ? _buildSearchResults(adaptive)
                  : _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _currentProducts != null
                          ? _buildProdutosGrid(_currentProducts!, adaptive)
                          : _buildCategoriasGrid(_currentCategories, adaptive),
        ),
      ],
    );
  }

  Widget _buildCategoriasGrid(
    List<ExibicaoProdutoListItemDto> categorias,
    AdaptiveLayoutProvider adaptive,
  ) {
    if (categorias.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma categoria encontrada',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(adaptive.isMobile ? 16 : 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getCrossAxisCount(adaptive),
        crossAxisSpacing: adaptive.isMobile ? 12 : 16,
        mainAxisSpacing: adaptive.isMobile ? 12 : 16,
        // Altura fixa para manter padrão com cards de produto
        mainAxisExtent: adaptive.isMobile ? 200 : 220,
      ),
      itemCount: categorias.length,
      itemBuilder: (context, index) {
        final categoria = categorias[index];
        return _buildCategoriaCard(categoria, adaptive);
      },
    );
  }

  Widget _buildCategoriaCard(
    ExibicaoProdutoListItemDto categoria,
    AdaptiveLayoutProvider adaptive,
  ) {
    final hasChildren = categoria.quantidadeCategoriasFilhas > 0;
    final hasProducts = categoria.quantidadeProdutos > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onCategoriaSelected(categoria),
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 16 : 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(adaptive.isMobile ? 16 : 20),
            border: Border.all(
              color: (categoria.cor != null ? _parseColor(categoria.cor!) : AppTheme.restauranteColor)
                  .withOpacity(0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(adaptive.isMobile ? 12 : 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Imagem/ícone com destaque e overlay suave
                Container(
                  width: adaptive.isMobile ? 84 : 100,
                  height: adaptive.isMobile ? 84 : 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(adaptive.isMobile ? 18 : 20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        (categoria.cor != null ? _parseColor(categoria.cor!) : AppTheme.restauranteColor)
                            .withOpacity(0.18),
                        Colors.white,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(adaptive.isMobile ? 18 : 20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        categoria.tipoRepresentacao == TipoRepresentacaoVisual.imagem &&
                          categoria.imagemFileName != null
                            ? _buildCategoriaImage(categoria, adaptive, fit: BoxFit.cover)
                            : Container(
                                color: Colors.white,
                                child: Icon(
                                  Icons.folder_open_rounded,
                                  size: adaptive.isMobile ? 36 : 40,
                                  color: categoria.cor != null
                                      ? _parseColor(categoria.cor!)
                                      : AppTheme.restauranteColor,
                                ),
                              ),
                        // Overlay suave para contraste do texto
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.0),
                                Colors.black.withOpacity(0.15),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Nome
                Padding(
                  padding: EdgeInsets.only(top: adaptive.isMobile ? 10 : 12),
                  child: Text(
                    categoria.nome,
                    style: GoogleFonts.inter(
                      fontSize: adaptive.isMobile ? 14 : 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriaImage(
    ExibicaoProdutoListItemDto categoria,
    AdaptiveLayoutProvider adaptive, {
    BoxFit fit = BoxFit.cover,
  }) {
                              final imageUrl = ImageUrlHelper.getThumbnailImageUrl(categoria.imagemFileName);
                              if (imageUrl == null || imageUrl.isEmpty) {
                                return Icon(
                                  Icons.image_outlined,
                                  size: adaptive.isMobile ? 32 : 40,
                                  color: AppTheme.restauranteColor,
                                );
                              }

                              return Image.network(
                                imageUrl,
      fit: fit,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('Erro ao carregar imagem: $error');
                                  debugPrint('URL tentada: $imageUrl');
                                  return Icon(
                                    Icons.image_outlined,
                                    size: adaptive.isMobile ? 32 : 40,
                                    color: AppTheme.restauranteColor,
                                  );
                                },
                              );
  }
  
  Widget _buildCrumbText({
    required String label,
    required VoidCallback onTap,
    required AdaptiveLayoutProvider adaptive,
    bool isActive = false,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.isMobile ? 10 : 12,
          vertical: adaptive.isMobile ? 6 : 6,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: isActive ? AppTheme.primaryColor : AppTheme.textPrimary,
                        ),
                        child: Text(
        label,
                          style: GoogleFonts.inter(
          fontSize: adaptive.isMobile ? 13 : 13.5,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
          color: isActive ? AppTheme.primaryColor : AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildProdutosGrid(
    List<ProdutoExibicaoBasicoDto> produtos,
    AdaptiveLayoutProvider adaptive,
  ) {
    if (produtos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum produto encontrado nesta categoria',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(adaptive.isMobile ? 16 : 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getCrossAxisCount(adaptive),
        crossAxisSpacing: adaptive.isMobile ? 12 : 16,
        mainAxisSpacing: adaptive.isMobile ? 12 : 16,
        // Altura fixa por item para não variar com a tela
        mainAxisExtent: adaptive.isMobile ? 210 : 230,
      ),
      itemCount: produtos.length,
      itemBuilder: (context, index) {
        final produto = produtos[index];
        return _buildProdutoCard(produto, adaptive);
      },
    );
  }

  Widget _buildProdutoCard(
    ProdutoExibicaoBasicoDto produto,
    AdaptiveLayoutProvider adaptive,
  ) {
    return Consumer<PedidoProvider>(
      builder: (context, pedidoProvider, child) {
        // Contar quantas vezes este produto foi adicionado ao pedido
        final quantidadeNoPedido = pedidoProvider.itens
            .where((item) => item.produtoId == produto.produtoId)
            .fold(0, (sum, item) => sum + item.quantidade);
        
        return Material(
          color: Colors.transparent,
          elevation: 0,
          child: InkWell(
            onTap: () => _onProdutoTapped(produto),
            borderRadius: BorderRadius.circular(adaptive.isMobile ? 16 : 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(adaptive.isMobile ? 16 : 20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(adaptive.isMobile ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Imagem/Ícone do produto com gradiente sutil
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: produto.produtoCor != null
                                ? [
                                    _parseColor(produto.produtoCor!).withOpacity(0.15),
                                    _parseColor(produto.produtoCor!).withOpacity(0.05),
                                  ]
                                : [
                                    AppTheme.restauranteColor.withOpacity(0.15),
                                    AppTheme.restauranteColor.withOpacity(0.05),
                                  ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: produto.produtoTipoRepresentacao == TipoRepresentacaoVisual.imagem &&
                                      produto.produtoImagemFileName != null
                                  ? ClipRRect(
                                      child: Image.network(
                                        ImageUrlHelper.getThumbnailImageUrl(produto.produtoImagemFileName) ?? '',
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.image_outlined,
                                            size: adaptive.isMobile ? 40 : 50,
                                            color: produto.produtoCor != null
                                                ? _parseColor(produto.produtoCor!)
                                                : AppTheme.restauranteColor,
                                          );
                                        },
                                      ),
                                    )
                                  : Icon(
                                      Icons.inventory_2,
                                      size: adaptive.isMobile ? 40 : 50,
                                      color: produto.produtoCor != null
                                          ? _parseColor(produto.produtoCor!)
                                          : AppTheme.restauranteColor,
                                    ),
                            ),
                            // Badge de quantidade se houver
                            if (quantidadeNoPedido > 0)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '$quantidadeNoPedido',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Conteúdo do card
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: adaptive.isMobile ? 10 : 12,
                          vertical: adaptive.isMobile ? 8 : 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    produto.produtoNome,
                                    style: GoogleFonts.inter(
                                      fontSize: adaptive.isMobile ? 13 : 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (produto.produtoPrecoVenda != null) ...[
                                    SizedBox(height: adaptive.isMobile ? 3 : 4),
                                    Text(
                                      'R\$ ${produto.produtoPrecoVenda!.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(
                                        fontSize: adaptive.isMobile ? 12 : 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.restauranteColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _adicionarRapido(produto),
                              onLongPress: () => _mostrarMenuRapido(produto),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  vertical: adaptive.isMobile ? 8 : 10,
                                ),
                                decoration: BoxDecoration(
                                  color: quantidadeNoPedido > 0 
                                      ? AppTheme.primaryColor 
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: quantidadeNoPedido > 0 
                                        ? AppTheme.primaryColor 
                                        : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      quantidadeNoPedido > 0 ? Icons.add_circle : Icons.add,
                                      color: quantidadeNoPedido > 0 
                                          ? Colors.white 
                                          : Colors.grey.shade700,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        quantidadeNoPedido > 0 ? 'Adicionar mais' : 'Adicionar',
                                        style: GoogleFonts.inter(
                                          fontSize: adaptive.isMobile ? 12 : 13,
                                          fontWeight: FontWeight.w600,
                                          color: quantidadeNoPedido > 0 
                                              ? Colors.white 
                                              : Colors.grey.shade700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Verifica se o produto pode ser adicionado rapidamente (sem variações/atributos)
  bool _podeAdicionarRapido(ProdutoLocal produto) {
    // Se tem variações, precisa selecionar
    if (produto.variacoes.isNotEmpty) return false;
    
    // Se tem atributos, precisa selecionar (assumindo que atributos sempre requerem seleção)
    if (produto.atributos.isNotEmpty) return false;
    
    return true;
  }

  int _getCrossAxisCount(AdaptiveLayoutProvider adaptive) {
    final width = adaptive.screenWidth;

    if (adaptive.isMobile) return 2;
    if (width >= 1700) return 6;
    if (width >= 1440) return 5;
    if (width >= 1200) return 4;
    return 3;
  }

  /// Adiciona produto rapidamente (quando possível)
  Future<void> _adicionarRapido(ProdutoExibicaoBasicoDto produtoDto) async {
    try {
      final produto = _produtoRepo.buscarPorId(produtoDto.produtoId);
      if (produto == null) {
        // Se não encontrou, abrir modal
        _onProdutoTapped(produtoDto);
        return;
      }

      // Verificar se pode adicionar rapidamente
      if (!_podeAdicionarRapido(produto)) {
        // Se não pode, mostrar menu rápido ou abrir modal
        _mostrarMenuRapido(produtoDto);
        return;
      }

      // Adicionar rapidamente
      final pedidoProvider = Provider.of<PedidoProvider>(context, listen: false);
      final preco = produto.precoVenda ?? 0.0;
      
      pedidoProvider.adicionarItens(
        ProdutoSelecionadoResult(
          itens: [
            ItemProdutoSelecionado(
              produtoId: produto.id,
              produtoNome: produto.nome,
              precoUnitario: preco,
            ),
          ],
        ),
      );

      // Feedback visual
      if (mounted) {
        AppToast.showSuccess(
          context,
          '${produto.nome} adicionado ao pedido',
        );
      }
    } catch (e) {
      debugPrint('Erro ao adicionar rapidamente: $e');
      // Em caso de erro, abrir modal
      _onProdutoTapped(produtoDto);
    }
  }

  /// Mostra menu rápido com variações principais
  void _mostrarMenuRapido(ProdutoExibicaoBasicoDto produtoDto) {
    final produto = _produtoRepo.buscarPorId(produtoDto.produtoId);
    if (produto == null) {
      _onProdutoTapped(produtoDto);
      return;
    }

    // Se não tem variações, abrir modal completo
    if (produto.variacoes.isEmpty) {
      _onProdutoTapped(produtoDto);
      return;
    }

    // Mostrar menu com todas as variações (com scroll)
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Título
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Adicionar ${produto.nome}',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${produto.variacoes.length} ${produto.variacoes.length == 1 ? 'opção disponível' : 'opções disponíveis'}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Lista de variações com scroll
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: produto.variacoes.length,
                itemBuilder: (context, index) {
                  final variacao = produto.variacoes[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.restaurant,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      variacao.nomeCompleto,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      'R\$ ${variacao.precoEfetivo.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _adicionarVariacaoRapida(produto, variacao);
                    },
                  );
                },
              ),
            ),
            // Botão para ver mais opções (abre modal completo)
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _onProdutoTapped(produtoDto);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Ver mais opções',
                      style: GoogleFonts.inter(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18, color: AppTheme.primaryColor),
                  ],
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  /// Adiciona uma variação rapidamente
  void _adicionarVariacaoRapida(ProdutoLocal produto, ProdutoVariacaoLocal variacao) {
    final pedidoProvider = Provider.of<PedidoProvider>(context, listen: false);
    
    pedidoProvider.adicionarItens(
      ProdutoSelecionadoResult(
        itens: [
          ItemProdutoSelecionado(
            produtoId: produto.id,
            produtoNome: produto.nome,
            produtoVariacaoId: variacao.id,
            produtoVariacaoNome: variacao.nomeCompleto,
            precoUnitario: variacao.precoEfetivo,
          ),
        ],
      ),
    );

    // Feedback visual
    if (mounted) {
      AppToast.showSuccess(
        context,
        '${variacao.nomeCompleto} adicionado ao pedido',
      );
    }
  }

  Future<void> _onProdutoTapped(ProdutoExibicaoBasicoDto produto) async {
    // Abrir modal de seleção de produto
    final result = await SelecionarProdutoModal.show(
      context,
      produtoId: produto.produtoId,
      produtoNome: produto.produtoNome,
      precoBase: produto.produtoPrecoVenda,
    );

    if (result != null && result.itens.isNotEmpty) {
      // Adicionar itens ao pedido através do provider
      final pedidoProvider = Provider.of<PedidoProvider>(context, listen: false);
      pedidoProvider.adicionarItens(result);
      
      // Mostrar feedback visual
      if (mounted) {
        AppToast.showSuccess(
          context,
          '${result.quantidade} ${result.quantidade == 1 ? 'item adicionado' : 'itens adicionados'} ao pedido',
        );
      }
      
      // Chamar callback se necessário (para compatibilidade)
      final primeiroItem = result.itens.first;
      final produtoSelecionado = ProdutoExibicaoBasicoDto(
        produtoId: primeiroItem.produtoId,
        produtoNome: primeiroItem.produtoNome,
        produtoSKU: produto.produtoSKU,
        produtoPrecoVenda: primeiroItem.precoUnitario,
        produtoImagemFileName: produto.produtoImagemFileName,
        produtoTipoRepresentacao: produto.produtoTipoRepresentacao,
        produtoIcone: produto.produtoIcone,
        produtoCor: produto.produtoCor,
        ordem: produto.ordem,
      );
      
      widget.onProdutoSelected(produtoSelecionado);
    }
  }

  Widget _buildCategoriaTab({
    required ExibicaoProdutoListItemDto categoria,
    required bool isSelected,
    String? imageUrl,
    required Color categoriaColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? categoriaColor : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: categoriaColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Imagem de fundo ou gradiente
              if (imageUrl != null)
                Positioned.fill(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildGradientBackground(categoriaColor);
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildGradientBackground(categoriaColor);
                    },
                  ),
                )
              else
                _buildGradientBackground(categoriaColor),
              
              // Overlay escuro para melhorar legibilidade
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.4),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Conteúdo
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ícone ou indicador de seleção
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (categoria.icone != null && categoria.icone!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _parseIcon(categoria.icone!),
                                size: 18,
                                color: categoriaColor,
                              ),
                            )
                          else
                            const SizedBox(width: 30),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: categoriaColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      
                      // Nome da categoria
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoria.nome,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (categoria.quantidadeProdutos > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${categoria.quantidadeProdutos} ${categoria.quantidadeProdutos == 1 ? 'produto' : 'produtos'}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.9),
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientBackground(Color baseColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            baseColor.withOpacity(0.7),
            baseColor.withOpacity(0.5),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(AdaptiveLayoutProvider adaptive) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum produto encontrado',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tente buscar com outros termos',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return _buildProdutosGrid(_searchResults, adaptive);
  }

  IconData _parseIcon(String iconName) {
    // Mapear nomes de ícones comuns para IconData
    final iconMap = {
      'restaurant': Icons.restaurant,
      'local_pizza': Icons.local_pizza,
      'fastfood': Icons.fastfood,
      'lunch_dining': Icons.lunch_dining,
      'dining': Icons.dining,
      'cake': Icons.cake,
      'local_drink': Icons.local_drink,
      'coffee': Icons.coffee,
      'icecream': Icons.icecream,
      'bakery_dining': Icons.bakery_dining,
      'set_meal': Icons.set_meal,
      'food_bank': Icons.food_bank,
    };
    
    return iconMap[iconName.toLowerCase()] ?? Icons.restaurant;
  }

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppTheme.restauranteColor;
    }
  }

  /// Converte ExibicaoProdutoLocal para ExibicaoProdutoListItemDto
  ExibicaoProdutoListItemDto _mapExibicaoLocalToListItemDto(ExibicaoProdutoLocal local) {
    return ExibicaoProdutoListItemDto(
      id: local.id,
      nome: local.nome,
      descricao: local.descricao,
      ordem: local.ordem,
      tipoRepresentacao: local.tipoRepresentacaoEnum,
      icone: local.icone,
      cor: local.cor,
      imagemFileName: local.imagemFileName,
      isAtiva: local.isAtiva,
      categoriaPaiId: local.categoriaPaiId,
      quantidadeCategoriasFilhas: _exibicaoRepo.contarCategoriasFilhas(local.id),
      quantidadeProdutos: _exibicaoRepo.contarProdutos(local.id),
    );
  }

  /// Converte ProdutoLocal para ProdutoExibicaoBasicoDto
  ProdutoExibicaoBasicoDto _mapProdutoLocalToExibicaoBasico(ProdutoLocal produto, int ordem) {
    return ProdutoExibicaoBasicoDto(
      produtoId: produto.id,
      produtoNome: produto.nome,
      produtoSKU: produto.sku,
      produtoPrecoVenda: produto.precoVenda,
      produtoImagemFileName: produto.imagemFileName,
      produtoTipoRepresentacao: produto.tipoRepresentacaoEnum,
      produtoIcone: produto.icone,
      produtoCor: produto.cor,
      ordem: ordem,
    );
  }
}

