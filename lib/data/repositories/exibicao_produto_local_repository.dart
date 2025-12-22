import 'package:hive_flutter/hive_flutter.dart';
import '../models/local/exibicao_produto_local.dart';
import '../models/sync/exibicao_produto_pdv_sync_dto.dart';

class ExibicaoProdutoLocalRepository {
  static const String _boxName = 'exibicao_produtos';
  Box<ExibicaoProdutoLocal>? _box;

  Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
    _box = await Hive.openBox<ExibicaoProdutoLocal>(_boxName);
    }
  }

  /// Salva todos os grupos (substitui existentes)
  /// Salva recursivamente todas as categorias (raiz e filhas) como entradas separadas
  Future<void> salvarTodos(List<ExibicaoProdutoPdvSyncDto> gruposDto) async {
    if (_box == null) {
      throw Exception('Repository não inicializado. Chame init() primeiro.');
    }

    print('📦 DEBUG ExibicaoRepo: Recebidos ${gruposDto.length} grupos para salvar');

    await _box!.clear();

    int totalSalvas = 0;
    // Salvar recursivamente todas as categorias
    for (final dto in gruposDto) {
      final countAntes = totalSalvas;
      await _salvarCategoriaRecursiva(dto);
      totalSalvas++;
      print('  ✅ Salva categoria: ${dto.nome} (${dto.produtos.length} produtos, ${dto.categoriasFilhas.length} filhas)');
    }
    
    print('📦 DEBUG ExibicaoRepo: Total de ${totalSalvas} categorias salvas no Hive');
    print('📦 DEBUG ExibicaoRepo: Total no box após salvar: ${_box!.length}');
  }

  /// Salva uma categoria e todas suas filhas recursivamente
  Future<void> _salvarCategoriaRecursiva(ExibicaoProdutoPdvSyncDto dto) async {
    // Criar categoria local (sem categorias filhas aninhadas para evitar duplicação)
    final produtoIds = dto.produtos.map((p) => p.produtoId).toList();
    
    final categoriaLocal = ExibicaoProdutoLocal(
      id: dto.id,
      nome: dto.nome,
      descricao: dto.descricao,
      categoriaPaiId: dto.categoriaPaiId,
      ordem: dto.ordem,
      tipoRepresentacao: dto.tipoRepresentacao.value,
      icone: dto.icone,
      cor: dto.cor,
      imagemFileName: dto.imagemFileName,
      isAtiva: dto.isAtiva,
      produtoIds: produtoIds,
      categoriasFilhas: [], // Não salvar filhas aninhadas aqui
      ultimaSincronizacao: DateTime.now(),
    );

    // Salvar categoria atual
    await _box!.put(categoriaLocal.id, categoriaLocal);
    print('    💾 Salva categoria ${dto.nome}: ${produtoIds.length} produtos');

    // Salvar recursivamente todas as categorias filhas
    for (final filhaDto in dto.categoriasFilhas) {
      await _salvarCategoriaRecursiva(filhaDto);
    }
  }

  /// Busca categorias raiz
  List<ExibicaoProdutoLocal> buscarCategoriasRaiz() {
    if (_box == null) return [];
    return _box!.values
        .where((g) => g.categoriaPaiId == null && g.isAtiva)
        .toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));
  }

  /// Busca categorias filhas
  List<ExibicaoProdutoLocal> buscarCategoriasFilhas(String categoriaPaiId) {
    if (_box == null) return [];
    return _box!.values
        .where((g) => g.categoriaPaiId == categoriaPaiId && g.isAtiva)
        .toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));
  }

  /// Busca categoria por ID
  ExibicaoProdutoLocal? buscarPorId(String id) {
    final categoria = _box?.get(id);
    return categoria;
  }

  /// Busca produtos de uma categoria
  List<String> buscarProdutosPorCategoria(String categoriaId) {
    final categoria = _box?.get(categoriaId);
    return categoria?.produtoIds ?? [];
  }

  /// Busca todas as categorias (para construção de árvore)
  List<ExibicaoProdutoLocal> buscarTodas() {
    if (_box == null) return [];
    return _box!.values
        .where((g) => g.isAtiva)
        .toList();
  }

  /// Conta categorias filhas de uma categoria
  int contarCategoriasFilhas(String categoriaId) {
    if (_box == null) return 0;
    return _box!.values
        .where((g) => g.categoriaPaiId == categoriaId && g.isAtiva)
        .length;
  }

  /// Conta produtos de uma categoria
  int contarProdutos(String categoriaId) {
    final categoria = _box?.get(categoriaId);
    return categoria?.produtoIds.length ?? 0;
  }

  /// Método auxiliar para mapear DTO para Local (mantido para compatibilidade)
  /// Nota: Este método não é mais usado em salvarTodos, mas pode ser útil em outros contextos
  ExibicaoProdutoLocal _mapDtoToLocal(ExibicaoProdutoPdvSyncDto dto) {
    return ExibicaoProdutoLocal(
      id: dto.id,
      nome: dto.nome,
      descricao: dto.descricao,
      categoriaPaiId: dto.categoriaPaiId,
      ordem: dto.ordem,
      tipoRepresentacao: dto.tipoRepresentacao.value,
      icone: dto.icone,
      cor: dto.cor,
      imagemFileName: dto.imagemFileName,
      isAtiva: dto.isAtiva,
      produtoIds: dto.produtos.map((p) => p.produtoId).toList(),
      categoriasFilhas: dto.categoriasFilhas.map(_mapDtoToLocal).toList(),
      ultimaSincronizacao: DateTime.now(),
    );
  }
}

