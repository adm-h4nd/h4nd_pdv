import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/local/produto_local.dart';
import '../models/local/produto_atributo_local.dart';
import '../models/local/produto_variacao_local.dart';
import '../models/local/produto_composicao_local.dart';
import '../models/sync/produto_pdv_sync_dto.dart';

class ProdutoLocalRepository {
  static const String _boxName = 'produtos';
  Box<ProdutoLocal>? _box;
  List<ProdutoLocal>? _cache;
  DateTime? _cacheTimestamp;

  Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
      try {
        _box = await Hive.openBox<ProdutoLocal>(_boxName);
        _carregarCache();
      } catch (e) {
        debugPrint('⚠️ Erro ao abrir box produtos (schema pode estar desatualizado): $e');
        // Se houver erro, tentar deletar o box e recriar
        try {
          await Hive.deleteBoxFromDisk(_boxName);
          debugPrint('✅ Box produtos deletado e será recriado');
        } catch (deleteError) {
          debugPrint('⚠️ Erro ao deletar box: $deleteError');
        }
    _box = await Hive.openBox<ProdutoLocal>(_boxName);
    _carregarCache();
      }
    }
  }

  void _carregarCache() {
    if (_box == null) return;
    try {
    _cache = _box!.values
        .where((p) => p.isAtivo && p.isVendavel)
        .toList();
    _cacheTimestamp = DateTime.now();
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar cache (dados podem ter schema antigo): $e');
      _cache = [];
      _cacheTimestamp = DateTime.now();
    }
  }

  void invalidarCache() {
    _cache = null;
    _cacheTimestamp = null;
  }

  List<ProdutoLocal> _obterProdutos() {
    if (_cache != null) {
      return _cache!;
    }
    _carregarCache();
    return _cache ?? [];
  }

  /// Salva todos os produtos (substitui existentes)
  Future<void> salvarTodos(List<ProdutoPdvSyncDto> produtosDto) async {
    // Garantir que está inicializado
    if (_box == null || !_box!.isOpen) {
      await init();
    }

    if (_box == null) {
      throw Exception('Repository não inicializado. Chame init() primeiro.');
    }

    // Limpar box existente (importante para evitar problemas com schemas antigos)
    try {
    await _box!.clear();
    } catch (e) {
      debugPrint('⚠️ Erro ao limpar box (pode ter dados antigos): $e');
      // Tentar deletar e recriar o box se houver erro
      try {
        await _box!.close();
        await Hive.deleteBoxFromDisk(_boxName);
        _box = await Hive.openBox<ProdutoLocal>(_boxName);
        debugPrint('✅ Box produtos recriado após erro');
      } catch (recreateError) {
        debugPrint('❌ Erro ao recriar box: $recreateError');
        rethrow;
      }
    }

    // Converter DTOs para modelos locais e salvar
    int produtosComComposicao = 0;
    int totalComposicoes = 0;
    for (final dto in produtosDto) {
      final produtoLocal = _mapDtoToLocal(dto);
      
      // DEBUG: Verificar composição antes de salvar
      if (produtoLocal.composicao.isNotEmpty) {
        produtosComComposicao++;
        totalComposicoes += produtoLocal.composicao.length;
        debugPrint('💾 Salvando produto ${produtoLocal.nome} com ${produtoLocal.composicao.length} itens de composição');
      }
      
      // Verificar composição nas variações
      for (var variacao in produtoLocal.variacoes) {
        if (variacao.composicao.isNotEmpty) {
          debugPrint('💾 Variação ${variacao.nomeCompleto} tem ${variacao.composicao.length} itens de composição');
        }
      }
      
      await _box!.put(produtoLocal.id, produtoLocal);
    }

    debugPrint('📊 Total de produtos salvos: ${produtosDto.length}');
    debugPrint('📊 Produtos com composição direta: $produtosComComposicao (total de $totalComposicoes itens)');
    
    // DEBUG: Verificar se a composição foi salva corretamente lendo de volta
    for (var dto in produtosDto) {
      if (dto.composicao.isNotEmpty) {
        final produtoSalvo = _box!.get(dto.id);
        if (produtoSalvo != null) {
          if (produtoSalvo.composicao.isEmpty) {
            debugPrint('❌ ERRO: Produto ${produtoSalvo.nome} foi salvo SEM composição! Esperado: ${dto.composicao.length} itens');
          } else {
            debugPrint('✅ Produto ${produtoSalvo.nome} salvo com ${produtoSalvo.composicao.length} itens de composição');
          }
        }
      }
      
      // Verificar composição nas variações
      for (var variacaoDto in dto.variacoes) {
        if (variacaoDto.composicao.isNotEmpty) {
          final produtoSalvo = _box!.get(dto.id);
          if (produtoSalvo != null) {
            final variacaoSalva = produtoSalvo.variacoes.firstWhere(
              (v) => v.id == variacaoDto.id,
              orElse: () => throw Exception('Variação não encontrada'),
            );
            if (variacaoSalva.composicao.isEmpty) {
              debugPrint('❌ ERRO: Variação ${variacaoSalva.nomeCompleto} foi salva SEM composição! Esperado: ${variacaoDto.composicao.length} itens');
            } else {
              debugPrint('✅ Variação ${variacaoSalva.nomeCompleto} salva com ${variacaoSalva.composicao.length} itens de composição');
            }
          }
        }
      }
    }

    invalidarCache();
  }

  /// Busca produto por ID
  ProdutoLocal? buscarPorId(String id) {
    final produto = _box?.get(id);
    if (produto != null) {
      // DEBUG: Verificar composição ao buscar
      if (produto.composicao.isNotEmpty) {
        debugPrint('🔍 Produto ${produto.nome} encontrado com ${produto.composicao.length} itens de composição');
      }
      for (var variacao in produto.variacoes) {
        if (variacao.composicao.isNotEmpty) {
          debugPrint('🔍 Variação ${variacao.nomeCompleto} tem ${variacao.composicao.length} itens de composição');
        }
      }
    }
    return produto;
  }

  /// Lista todos os produtos ativos e vendáveis
  List<ProdutoLocal> listarTodos() {
    return _obterProdutos()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }

  /// Busca produtos por nome (case-insensitive)
  List<ProdutoLocal> buscarPorNome(String termo) {
    final termoLower = termo.toLowerCase();
    return _obterProdutos()
        .where((p) =>
            p.nome.toLowerCase().contains(termoLower) ||
            (p.descricao?.toLowerCase().contains(termoLower) ?? false))
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }

  /// Filtra produtos por grupo
  List<ProdutoLocal> filtrarPorGrupo(String grupoId) {
    return _obterProdutos()
        .where((p) => p.grupoId == grupoId)
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }

  /// Filtra produtos por subgrupo
  List<ProdutoLocal> filtrarPorSubgrupo(String subgrupoId) {
    return _obterProdutos()
        .where((p) => p.subgrupoId == subgrupoId)
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }

  /// Conta total de produtos
  int contar() {
    return _obterProdutos().length;
  }

  /// Busca produtos por IDs
  List<ProdutoLocal> buscarPorIds(List<String> ids) {
    if (_box == null) return [];
    final produtos = ids
        .map((id) => _box!.get(id))
        .whereType<ProdutoLocal>()
        .toList();
    
    // DEBUG: Verificar composição ao buscar
    for (var produto in produtos) {
      if (produto.composicao.isNotEmpty) {
        debugPrint('🔍 Produto ${produto.nome} encontrado com ${produto.composicao.length} itens de composição');
      }
      for (var variacao in produto.variacoes) {
        if (variacao.composicao.isNotEmpty) {
          debugPrint('🔍 Variação ${variacao.nomeCompleto} tem ${variacao.composicao.length} itens de composição');
        }
      }
    }
    
    return produtos;
  }

  ProdutoLocal _mapDtoToLocal(ProdutoPdvSyncDto dto) {
    // DEBUG: Verificar composição antes do mapeamento
    debugPrint('🔍 Mapeando produto: ${dto.nome}');
    debugPrint('  Composição no DTO: ${dto.composicao.length} itens');
    
    if (dto.composicao.isNotEmpty) {
      debugPrint('  📋 Composição do produto:');
      for (var comp in dto.composicao) {
        debugPrint('    - ${comp.componenteNome} (ID: ${comp.componenteId}, Removível: ${comp.isRemovivel})');
      }
    }
    
    final composicaoMapeada = dto.composicao.isNotEmpty 
        ? dto.composicao.map<ProdutoComposicaoLocal>(_mapComposicaoDtoToLocal).toList()
        : <ProdutoComposicaoLocal>[];
    
    debugPrint('  Composição mapeada: ${composicaoMapeada.length} itens');
    
    return ProdutoLocal(
      id: dto.id,
      nome: dto.nome,
      descricao: dto.descricao,
      sku: dto.sku,
      referencia: dto.referencia,
      tipo: dto.tipo,
      precoVenda: dto.precoVenda,
      isControlaEstoque: dto.isControlaEstoque,
      isControlaEstoquePorVariacao: dto.isControlaEstoquePorVariacao,
      unidadeBase: dto.unidadeBase,
      grupoId: dto.grupoId,
      grupoNome: dto.grupoNome,
      grupoTipoRepresentacao: dto.grupoTipoRepresentacao?.value,
      grupoIcone: dto.grupoIcone,
      grupoCor: dto.grupoCor,
      grupoImagemFileName: dto.grupoImagemFileName,
      subgrupoId: dto.subgrupoId,
      subgrupoNome: dto.subgrupoNome,
      subgrupoTipoRepresentacao: dto.subgrupoTipoRepresentacao?.value,
      subgrupoIcone: dto.subgrupoIcone,
      subgrupoCor: dto.subgrupoCor,
      subgrupoImagemFileName: dto.subgrupoImagemFileName,
      tipoRepresentacao: dto.tipoRepresentacao.value,
      icone: dto.icone,
      cor: dto.cor,
      imagemFileName: dto.imagemFileName,
      atributos: dto.atributos.map(_mapAtributoDtoToLocal).toList(),
      variacoes: dto.variacoes.map(_mapVariacaoDtoToLocal).toList(),
      composicao: composicaoMapeada,
      isAtivo: dto.isAtivo,
      isVendavel: dto.isVendavel,
      temVariacoes: dto.temVariacoes,
      ultimaSincronizacao: DateTime.now(),
    );
  }

  ProdutoAtributoLocal _mapAtributoDtoToLocal(ProdutoAtributoPdvSyncDto dto) {
    return ProdutoAtributoLocal(
      id: dto.id,
      produtoId: dto.produtoId,
      atributoId: dto.atributoId,
      nome: dto.nome,
      descricao: dto.descricao,
      permiteSelecaoProporcional: dto.permiteSelecaoProporcional,
      ordem: dto.ordem,
      valores: dto.valores.map(_mapValorDtoToLocal).toList(),
    );
  }

  ProdutoAtributoValorLocal _mapValorDtoToLocal(ProdutoAtributoValorPdvSyncDto dto) {
    return ProdutoAtributoValorLocal(
      id: dto.id,
      atributoValorId: dto.atributoValorId,
      nome: dto.nome,
      descricao: dto.descricao,
      ordem: dto.ordem,
      isActive: dto.isActive,
    );
  }

  ProdutoVariacaoLocal _mapVariacaoDtoToLocal(ProdutoVariacaoPdvSyncDto dto) {
    // DEBUG: Verificar valores antes do mapeamento
    debugPrint('🔍 Mapeando variação: ${dto.nomeCompleto}');
    debugPrint('  Valores no DTO: ${dto.valores.length}');
    debugPrint('  Composição no DTO: ${dto.composicao.length} itens');
    
    if (dto.composicao.isNotEmpty) {
      debugPrint('  📋 Composição da variação:');
      for (var comp in dto.composicao) {
        debugPrint('    - ${comp.componenteNome} (ID: ${comp.componenteId}, Removível: ${comp.isRemovivel})');
      }
    }
    
    if (dto.valores.isEmpty) {
      debugPrint('  ⚠️ ATENÇÃO: Variação ${dto.nomeCompleto} não tem valores no DTO!');
    } else {
      for (var valor in dto.valores) {
        debugPrint('    - ${valor.nomeAtributo}: ${valor.nomeValor} (atributoValorId: ${valor.atributoValorId})');
      }
    }
    
    final valoresMapeados = dto.valores.map(_mapVariacaoValorDtoToLocal).toList();
    debugPrint('  Valores mapeados: ${valoresMapeados.length}');
    
    final composicaoMapeada = dto.composicao.isNotEmpty
        ? dto.composicao.map<ProdutoComposicaoLocal>(_mapComposicaoDtoToLocal).toList()
        : <ProdutoComposicaoLocal>[];
    
    debugPrint('  Composição mapeada: ${composicaoMapeada.length} itens');
    
    return ProdutoVariacaoLocal(
      id: dto.id,
      produtoId: dto.produtoId,
      nome: dto.nome,
      nomeCompleto: dto.nomeCompleto,
      descricao: dto.descricao,
      precoVenda: dto.precoVenda,
      precoEfetivo: dto.precoEfetivo,
      sku: dto.sku,
      ordem: dto.ordem,
      valores: valoresMapeados,
      tipoRepresentacaoVisual: dto.tipoRepresentacaoVisual?.value,
      icone: dto.icone,
      cor: dto.cor,
      imagemFileName: dto.imagemFileName,
      composicao: composicaoMapeada,
    );
  }

  ProdutoComposicaoLocal _mapComposicaoDtoToLocal(ProdutoComposicaoPdvSyncDto dto) {
    return ProdutoComposicaoLocal(
      componenteId: dto.componenteId,
      componenteNome: dto.componenteNome,
      isRemovivel: dto.isRemovivel,
      ordem: dto.ordem,
    );
  }

  ProdutoVariacaoValorLocal _mapVariacaoValorDtoToLocal(ProdutoVariacaoValorPdvSyncDto dto) {
    return ProdutoVariacaoValorLocal(
      id: dto.id,
      produtoVariacaoId: dto.produtoVariacaoId,
      atributoValorId: dto.atributoValorId,
      nomeAtributo: dto.nomeAtributo,
      nomeValor: dto.nomeValor,
    );
  }
}

