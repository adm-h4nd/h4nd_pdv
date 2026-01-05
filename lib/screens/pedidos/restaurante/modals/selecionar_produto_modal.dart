import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../presentation/providers/services_provider.dart';
import '../../../../data/repositories/produto_local_repository.dart';
import '../../../../data/models/local/produto_local.dart';
import '../../../../data/models/local/produto_atributo_local.dart';
import '../../../../data/models/local/produto_variacao_local.dart';
import '../../../../data/models/local/produto_composicao_local.dart';
import '../../../../data/models/core/produtos.dart';

/// Item individual do produto selecionado
class ItemProdutoSelecionado {
  final String produtoId;
  final String produtoNome;
  final String? produtoVariacaoId;
  final String? produtoVariacaoNome;
  final double precoUnitario;
  final String? observacoes;
  final Map<String, double>? proporcoesAtributos; // Map<valorId, proporcao> para atributos proporcionais
  final Map<String, List<String>>? valoresAtributosSelecionados; // Map<atributoId, List<valorId>> - valores selecionados para cada atributo
  final List<String> componentesRemovidos; // Lista de IDs dos componentes removidos da composição

  ItemProdutoSelecionado({
    required this.produtoId,
    required this.produtoNome,
    this.produtoVariacaoId,
    this.produtoVariacaoNome,
    required this.precoUnitario,
    this.observacoes,
    this.proporcoesAtributos,
    this.valoresAtributosSelecionados,
    this.componentesRemovidos = const [],
  });
}

/// Resultado da seleção de produto
class ProdutoSelecionadoResult {
  final List<ItemProdutoSelecionado> itens;

  ProdutoSelecionadoResult({
    required this.itens,
  });

  // Helper para compatibilidade: retorna quantidade total
  int get quantidade => itens.length;
  
  // Helper: retorna o primeiro item (para casos simples)
  ItemProdutoSelecionado get primeiroItem => itens.first;
}

/// Modal para seleção de produto com atributos e variações
class SelecionarProdutoModal extends StatefulWidget {
  final String produtoId;
  final String produtoNome;
  final double? precoBase;

  const SelecionarProdutoModal({
    super.key,
    required this.produtoId,
    required this.produtoNome,
    this.precoBase,
  });

  @override
  State<SelecionarProdutoModal> createState() => _SelecionarProdutoModalState();

  static Future<ProdutoSelecionadoResult?> show(
    BuildContext context, {
    required String produtoId,
    required String produtoNome,
    double? precoBase,
  }) async {
    // SEMPRE abre como TELA CHEIA usando PageRouteBuilder
    return await Navigator.of(context, rootNavigator: true).push<ProdutoSelecionadoResult>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SelecionarProdutoModal(
          produtoId: produtoId,
          produtoNome: produtoNome,
          precoBase: precoBase,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        opaque: true,
        fullscreenDialog: false,
      ),
    );
  }
}

class _SelecionarProdutoModalState extends State<SelecionarProdutoModal> {
  ProdutoLocal? _produto;
  bool _isLoading = true;

  // Estado da seleção
  final Map<String, List<String>> _selecoesAtributos = {}; // Map<atributoId, List<valorId>>
  final Map<String, Map<String, double>> _proporcoesAtributos = {}; // Map<atributoId, Map<valorId, proporcao>>
  final Map<String, bool> _atributosExpandidos = {}; // Map<atributoId, bool> - controla qual atributo está expandido
  final Map<String, bool> _proporcoesExpandidas = {}; // Map<atributoId, bool> - controla se as proporções estão expandidas
  int _quantidade = 1;
  int _atributoAtualIndex = 0; // Índice do atributo sendo visualizado no layout compacto
  
  // Estado de validação de disponibilidade
  List<Map<String, dynamic>>? _combinacoesIndisponiveis; // Lista de combinações que não têm variação disponível
  bool _atributosIncompletos = false; // Indica se os atributos não foram completamente selecionados
  
  // Lista de itens individuais (quando quantidade > 1)
  final List<Map<String, dynamic>> _itens = []; // Lista de mapas com {observacoes, variacaoId, variacaoNome, proporcoes, componentesRemovidos}
  final Map<int, bool> _itensExpandidos = {}; // Map<indexItem, bool> - controla qual item está expandido para editar observações
  final Map<int, bool> _itensComposicaoExpandidos = {}; // Map<indexItem, bool> - controla qual item está expandido para editar composição

  ProdutoLocalRepository get _produtoRepo {
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    return servicesProvider.produtoLocalRepo;
  }

  @override
  void initState() {
    super.initState();
    _carregarProduto();
    _inicializarItens();
  }

  /// Inicializa a lista de itens baseada na quantidade
  void _inicializarItens() {
    _itens.clear();
    for (int i = 0; i < _quantidade; i++) {
      _itens.add({
        'observacoes': '',
        'variacaoId': null,
        'variacaoNome': null,
        'proporcoes': null,
        'componentesRemovidos': <String>[],
      });
    }
  }

  /// Atualiza a quantidade e ajusta a lista de itens
  void _atualizarQuantidade(int novaQuantidade) {
    if (novaQuantidade < 1) return;
    
    setState(() {
      if (novaQuantidade > _quantidade) {
        // Adicionar novos itens
        for (int i = _quantidade; i < novaQuantidade; i++) {
          final variacao = _obterVariacaoSelecionada();
          _itens.add({
            'observacoes': '',
            'variacaoId': variacao?.id,
            'variacaoNome': variacao?.nomeCompleto,
            'proporcoes': _proporcoesAtributos.isNotEmpty 
                ? Map<String, double>.from(_proporcoesAtributos.map((k, v) => MapEntry(k, v.values.first)))
                : null,
            'componentesRemovidos': <String>[],
          });
        }
      } else if (novaQuantidade < _quantidade) {
        // Remover itens do final
        _itens.removeRange(novaQuantidade, _quantidade);
        // Limpar estados expandidos dos itens removidos
        _itensExpandidos.removeWhere((key, value) => key >= novaQuantidade);
      }
      _quantidade = novaQuantidade;
    });
  }

  /// Remove um item específico da lista
  void _removerItem(int index) {
    if (_itens.length <= 1) return;
    
    setState(() {
      _itens.removeAt(index);
      _quantidade = _itens.length;
      // Ajustar índices dos itens expandidos
      final novosExpandidos = <int, bool>{};
      _itensExpandidos.forEach((key, value) {
        if (key < index) {
          novosExpandidos[key] = value;
        } else if (key > index) {
          novosExpandidos[key - 1] = value;
        }
      });
      _itensExpandidos.clear();
      _itensExpandidos.addAll(novosExpandidos);
    });
  }

  /// Atualiza observações de um item específico
  void _atualizarObservacoesItem(int index, String observacoes) {
    setState(() {
      _itens[index]['observacoes'] = observacoes;
    });
  }

  /// Alterna expansão de um item para editar observações
  void _alternarExpansaoItem(int index) {
    setState(() {
      _itensExpandidos[index] = !(_itensExpandidos[index] ?? false);
    });
  }

  /// Alterna expansão de um item para editar composição
  void _alternarExpansaoComposicaoItem(int index) {
    setState(() {
      _itensComposicaoExpandidos[index] = !(_itensComposicaoExpandidos[index] ?? false);
    });
  }

  /// Alterna remoção de um componente em um item específico
  void _alternarComponenteRemovido(int indexItem, String componenteId) {
    setState(() {
      final componentesRemovidos = List<String>.from(_itens[indexItem]['componentesRemovidos'] ?? []);
      if (componentesRemovidos.contains(componenteId)) {
        componentesRemovidos.remove(componenteId);
      } else {
        componentesRemovidos.add(componenteId);
      }
      _itens[indexItem]['componentesRemovidos'] = componentesRemovidos;
    });
  }

  /// Obtém a lista de composição para um item específico (produto ou variação)
  List<ProdutoComposicaoLocal> _obterComposicaoItem(int indexItem) {
    final variacaoId = _itens[indexItem]['variacaoId'] as String?;
    
    // Se tem variação, buscar composição da variação
    if (variacaoId != null && _produto != null) {
      try {
        final variacao = _produto!.variacoes.firstWhere(
          (v) => v.id == variacaoId,
        );
        return variacao.composicao.isNotEmpty ? variacao.composicao : [];
      } catch (e) {
        // Variação não encontrada, usar composição do produto
      }
    }
    
    // Caso contrário, buscar composição direta do produto
    return _produto?.composicao.isNotEmpty == true ? _produto!.composicao : [];
  }

  /// Verifica se um componente está removido em um item específico
  bool _isComponenteRemovido(int indexItem, String componenteId) {
    final componentesRemovidos = _itens[indexItem]['componentesRemovidos'] as List<String>? ?? [];
    return componentesRemovidos.contains(componenteId);
  }

  Future<void> _carregarProduto() async {
    try {
      final produto = _produtoRepo.buscarPorId(widget.produtoId);
      
      if (produto == null) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produto não encontrado')),
          );
        }
        return;
      }

        setState(() {
        _produto = produto;
        // Expandir o primeiro atributo por padrão
        if (produto.atributos.isNotEmpty) {
          _atributosExpandidos[produto.atributos.first.id] = true;
        }
          _isLoading = false;
      });
      
      // Inicializar itens após carregar o produto
      _inicializarItens();
    } catch (e) {
      debugPrint('Erro ao carregar produto: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  /// Obtém valores disponíveis para um atributo (sempre retorna todos os valores ativos)
  List<ProdutoAtributoValorLocal> _obterValoresDisponiveis(ProdutoAtributoLocal atributo) {
    // Sempre retorna todos os valores ativos do atributo, sem filtro
    return atributo.valores.where((v) => v.isActive).toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));
  }

  /// Verifica se um atributo já foi completamente selecionado
  bool _atributoCompleto(ProdutoAtributoLocal atributo) {
    final selecoes = _selecoesAtributos[atributo.id] ?? [];
    if (selecoes.isEmpty) return false;
    
    if (atributo.permiteSelecaoProporcional) {
      // Para proporcional, precisa ter pelo menos uma seleção
      return selecoes.isNotEmpty;
    } else {
      // Para não proporcional, precisa ter exatamente uma seleção
      return selecoes.length == 1;
    }
  }

  /// Alterna a expansão de um atributo
  void _alternarExpansao(String atributoId) {
      setState(() {
      _atributosExpandidos[atributoId] = !(_atributosExpandidos[atributoId] ?? false);
      });
  }

  /// Seleciona um valor de atributo
  void _selecionarValor(ProdutoAtributoLocal atributo, ProdutoAtributoValorLocal valor) {
    // Limpar estado de indisponibilidade ao alterar seleções
    _combinacoesIndisponiveis = null;
    _atributosIncompletos = false;
    setState(() {
      final selecoes = _selecoesAtributos[atributo.id] ?? [];
      
      if (atributo.permiteSelecaoProporcional) {
        // Adicionar ou remover da lista (permite múltiplas seleções)
        if (selecoes.contains(valor.atributoValorId)) {
          selecoes.remove(valor.atributoValorId);
          _proporcoesAtributos[atributo.id]?.remove(valor.atributoValorId);
          // Se ainda há seleções, redistribuir proporções igualmente
          if (selecoes.isNotEmpty) {
            final proporcoes = _proporcoesAtributos[atributo.id] ?? {};
            final totalSelecoes = selecoes.length;
            for (var valorId in selecoes) {
              proporcoes[valorId] = 1.0 / totalSelecoes;
            }
            _proporcoesAtributos[atributo.id] = proporcoes;
          }
        } else {
          selecoes.add(valor.atributoValorId);
          // Inicializar proporção igualmente
          final proporcoes = _proporcoesAtributos[atributo.id] ?? {};
          final totalSelecoes = selecoes.length;
          // Redistribuir proporções igualmente
          for (var valorId in selecoes) {
            proporcoes[valorId] = 1.0 / totalSelecoes;
          }
          _proporcoesAtributos[atributo.id] = proporcoes;
        }
      } else {
        // Substituir seleção anterior (apenas uma seleção permitida)
        selecoes.clear();
        selecoes.add(valor.atributoValorId);
      }
      
      _selecoesAtributos[atributo.id] = selecoes;
    });
  }

  /// Atualiza proporção de um valor
  void _atualizarProporcao(ProdutoAtributoLocal atributo, String valorId, double proporcao) {
    // Limpar estado de indisponibilidade ao alterar proporções
    _combinacoesIndisponiveis = null;
    setState(() {
      final proporcoes = _proporcoesAtributos[atributo.id] ?? {};
      proporcoes[valorId] = proporcao;
      _proporcoesAtributos[atributo.id] = proporcoes;
      
      // Normalizar automaticamente após atualizar
      final soma = proporcoes.values.fold(0.0, (a, b) => a + b);
      if (soma > 0) {
        for (var key in proporcoes.keys) {
          proporcoes[key] = proporcoes[key]! / soma;
        }
      }
    });
  }

  /// Normaliza proporções para somar 1.0
  void _normalizarProporcoes(String atributoId) {
    final proporcoes = _proporcoesAtributos[atributoId];
    if (proporcoes == null || proporcoes.isEmpty) return;

    final soma = proporcoes.values.fold(0.0, (a, b) => a + b);
    if (soma == 0) return;

    setState(() {
      for (var key in proporcoes.keys) {
        proporcoes[key] = proporcoes[key]! / soma;
      }
    });
  }

  /// Verifica se pode confirmar a seleção
  bool _podeConfirmar() {
    if (_produto == null) {
      debugPrint('❌ _podeConfirmar: produto é null');
      return false;
    }
    
    // Se não tem variações, pode confirmar
    if (!_produto!.temVariacoes || _produto!.atributos.isEmpty) {
      debugPrint('✅ _podeConfirmar: produto sem variações ou sem atributos - pode confirmar');
      return true;
    }

    // Verificar se todos os atributos foram selecionados
    for (var atributo in _produto!.atributos) {
      if (!_atributoCompleto(atributo)) {
        debugPrint('❌ _podeConfirmar: atributo "${atributo.nome}" não está completo');
        debugPrint('   Seleções para ${atributo.nome}: ${_selecoesAtributos[atributo.id]}');
        return false;
      }
    }

    // Verificar se há atributos proporcionais
    final temAtributosProporcionais = _produto!.atributos.any((a) => a.permiteSelecaoProporcional);
    
    if (!temAtributosProporcionais) {
      // Sem proporções: verificar se há uma variação única que corresponde às seleções
      final variacao = _obterVariacaoSelecionada();
      if (variacao == null) {
        // Se não encontrou variação, mas todos os atributos estão completos,
        // pode ser que a variação não exista ainda ou há um problema na busca
        // Nesse caso, vamos permitir se o preço pode ser calculado
        debugPrint('⚠️ _podeConfirmar: nenhuma variação encontrada para seleções (sem proporções)');
        debugPrint('   Tentando calcular preço como fallback...');
        final preco = _calcularPrecoComProporcoes();
        if (preco != null) {
          debugPrint('✅ _podeConfirmar: preço calculado com sucesso: $preco');
          return true;
        }
        debugPrint('❌ _podeConfirmar: preço também não pode ser calculado');
        return false;
      }
      debugPrint('✅ _podeConfirmar: variação encontrada: ${variacao.nomeCompleto}');
    } else {
      debugPrint('ℹ️ _podeConfirmar: produto tem atributos proporcionais - verificando combinações');
    }
    
    // Verificar se todas as combinações têm variações disponíveis
    // (para proporções, isso verifica todas as combinações possíveis)
    final preco = _calcularPrecoComProporcoes();
    if (preco == null) {
      debugPrint('❌ _podeConfirmar: preço não pode ser calculado - combinações indisponíveis ou atributos incompletos');
      return false;
    }
    
    debugPrint('✅ _podeConfirmar: pode confirmar! Preço: $preco');
    return true;
  }

  /// Obtém a variação selecionada baseada nas seleções de atributos
  ProdutoVariacaoLocal? _obterVariacaoSelecionada() {
    if (_produto == null || _produto!.variacoes.isEmpty) {
      debugPrint('⚠️ _obterVariacaoSelecionada: produto é null ou não tem variações');
      return null;
    }
    
    // Se não há atributos proporcionais, buscar variação única que corresponde
    final temAtributosProporcionais = _produto!.atributos.any((a) => a.permiteSelecaoProporcional);
    
    if (!temAtributosProporcionais) {
      debugPrint('🔍 _obterVariacaoSelecionada: buscando variação (sem proporções)');
      debugPrint('   Seleções: $_selecoesAtributos');
      debugPrint('   Total de variações: ${_produto!.variacoes.length}');
      
      // Buscar variação que corresponde exatamente a todas as seleções
      for (var variacao in _produto!.variacoes) {
        bool corresponde = true;
        int atributosCorrespondentes = 0;
        
        // Verificar se a variação tem valores para todos os atributos selecionados
        for (var entry in _selecoesAtributos.entries) {
          final atributoId = entry.key;
          final valoresSelecionados = entry.value;
          
          if (valoresSelecionados.isEmpty) {
            corresponde = false;
            break;
          }
          
          final atributo = _produto!.atributos.firstWhere(
            (a) => a.id == atributoId,
            orElse: () => _produto!.atributos.first,
          );
          
          // Verificar se a variação tem algum valor que corresponde às seleções
          final temValor = variacao.valores.any((vv) {
            // Comparar por ID primeiro (mais confiável)
            if (valoresSelecionados.contains(vv.atributoValorId)) {
              return true;
            }
            // Comparar por nome como fallback
            if (vv.nomeAtributo == atributo.nome) {
              return atributo.valores.any((av) => 
                valoresSelecionados.contains(av.atributoValorId) &&
                av.nome == vv.nomeValor
              );
            }
            return false;
          });
          
          if (temValor) {
            atributosCorrespondentes++;
          } else {
            corresponde = false;
            break;
          }
        }
        
        // Verificar se todos os atributos do produto têm seleções correspondentes
        if (corresponde && atributosCorrespondentes == _produto!.atributos.length) {
          debugPrint('✅ _obterVariacaoSelecionada: variação encontrada: ${variacao.nomeCompleto}');
          return variacao;
        }
      }
      
      debugPrint('❌ _obterVariacaoSelecionada: nenhuma variação corresponde às seleções');
    }
    
    return null;
  }

  /// Calcula o preço baseado nas proporções de cada combinação
  /// Retorna null se alguma combinação não estiver disponível ou se atributos não estiverem completos
  double? _calcularPrecoComProporcoes() {
    if (_produto == null) {
      debugPrint('⚠️ _calcularPrecoComProporcoes: produto é null');
      _atributosIncompletos = false;
      return null; // Não usar fallback
    }
    
    // Definir preço padrão no início do método
    final precoPadrao = _produto!.precoVenda ?? widget.precoBase ?? 0.0;
    
    // Se não tem variações e não tem atributos, retornar preço do produto
    if ((!_produto!.temVariacoes || _produto!.variacoes.isEmpty) && 
        (_produto!.atributos.isEmpty)) {
      debugPrint('💰 Preço sem variações e sem atributos: $precoPadrao');
      _atributosIncompletos = false;
      return precoPadrao;
    }
    
    // Se tem atributos mas não tem variações, verificar se atributos foram selecionados
    if (!_produto!.temVariacoes || _produto!.variacoes.isEmpty) {
      // Verificar se todos os atributos foram selecionados
    final todosAtributosSelecionados = _produto!.atributos.every((a) {
      final selecoes = _selecoesAtributos[a.id] ?? [];
      return selecoes.isNotEmpty;
    });
    
    if (!todosAtributosSelecionados) {
        debugPrint('⚠️ Atributos não completos - não exibir preço');
        _atributosIncompletos = true;
        return null; // Retornar null quando atributos não estão completos
      }
      
      // Se todos os atributos foram selecionados mas não tem variações, usar preço padrão
      debugPrint('💰 Preço sem variações mas com atributos completos: $precoPadrao');
      _atributosIncompletos = false;
      return precoPadrao;
    }
    
    // Verificar se todos os atributos foram selecionados
    final todosAtributosSelecionados = _produto!.atributos.every((a) {
      final selecoes = _selecoesAtributos[a.id] ?? [];
      return selecoes.isNotEmpty;
    });
    
    if (!todosAtributosSelecionados) {
      debugPrint('⚠️ Atributos não completos - não exibir preço');
      _atributosIncompletos = true;
      return null; // Retornar null quando atributos não estão completos
    }
    
    // Limpar flag de atributos incompletos se chegou até aqui
    _atributosIncompletos = false;
    
    // Verificar se há atributos proporcionais
    final temAtributosProporcionais = _produto!.atributos.any((a) => a.permiteSelecaoProporcional);
    
    if (!temAtributosProporcionais) {
      // Sem proporções, usar variação única
      final variacao = _obterVariacaoSelecionada();
      if (variacao == null) {
        // Variação não encontrada - combinação não disponível
        debugPrint('❌ Variação não encontrada para combinação selecionada');
        _combinacoesIndisponiveis = [{}]; // Marcar como indisponível
        return null;
      }
      final preco = variacao.precoEfetivo;
      debugPrint('💰 Preço variação única: $preco (variação: ${variacao.nomeCompleto})');
      _combinacoesIndisponiveis = null; // Limpar estado de indisponibilidade
      return preco > 0 ? preco : precoPadrao;
    }
    
    // Com proporções: calcular preço médio ponderado
    final precoCalculado = _calcularPrecoMedioPonderado();
    if (precoCalculado == null) {
      debugPrint('❌ Preço não pode ser calculado - combinações indisponíveis');
      return null;
    }
    debugPrint('💰 Preço calculado com proporções: $precoCalculado');
    return precoCalculado > 0 ? precoCalculado : precoPadrao;
  }

  /// Calcula preço médio ponderado baseado nas proporções de cada combinação
  /// Retorna null se alguma combinação não estiver disponível
  double? _calcularPrecoMedioPonderado() {
    if (_produto == null) {
      debugPrint('⚠️ _calcularPrecoMedioPonderado: produto é null');
      return widget.precoBase ?? 1.0;
    }
    
    final precoPadrao = _produto!.precoVenda ?? widget.precoBase ?? 1.0;
    
    // LOG: Listar todas as variações disponíveis
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('📦 VARIAÇÕES DISPONÍVEIS PARA O PRODUTO: ${_produto!.nome}');
    debugPrint('═══════════════════════════════════════════════════════════');
    for (var i = 0; i < _produto!.variacoes.length; i++) {
      final variacao = _produto!.variacoes[i];
      debugPrint('Variação ${i + 1}:');
      debugPrint('  ID: ${variacao.id}');
      debugPrint('  Nome: ${variacao.nome ?? "N/A"}');
      debugPrint('  Nome Completo: ${variacao.nomeCompleto}');
      debugPrint('  Preço Venda: ${variacao.precoVenda}');
      debugPrint('  Preço Efetivo: ${variacao.precoEfetivo}');
      debugPrint('  Valores (${variacao.valores.length}):');
      for (var valor in variacao.valores) {
        debugPrint('    - ${valor.nomeAtributo}: ${valor.nomeValor} (atributoValorId: ${valor.atributoValorId})');
      }
      debugPrint('');
    }
    
    // LOG: Listar atributos e valores selecionados
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🎯 ATRIBUTOS E SELEÇÕES ATUAIS');
    debugPrint('═══════════════════════════════════════════════════════════');
    for (var atributo in _produto!.atributos) {
      final selecoes = _selecoesAtributos[atributo.id] ?? [];
      final proporcoes = _proporcoesAtributos[atributo.id] ?? {};
      debugPrint('Atributo: ${atributo.nome} (ID: ${atributo.id})');
      debugPrint('  Permite Proporcional: ${atributo.permiteSelecaoProporcional}');
      debugPrint('  Valores Selecionados: $selecoes');
      debugPrint('  Proporções: $proporcoes');
      debugPrint('  Todos os Valores Disponíveis:');
      for (var valor in atributo.valores) {
        final isSelected = selecoes.contains(valor.atributoValorId);
        final proporcao = proporcoes[valor.atributoValorId];
        debugPrint('    ${isSelected ? "✓" : " "} ${valor.nome} (ID: ${valor.atributoValorId})${proporcao != null ? " - ${(proporcao * 100).toStringAsFixed(1)}%" : ""}');
      }
      debugPrint('');
    }
    
    // Gerar todas as combinações possíveis de valores selecionados
    final combinacoes = _gerarCombinacoes();
    
    if (combinacoes.isEmpty) {
      debugPrint('⚠️ Nenhuma combinação gerada, usando preço padrão: $precoPadrao');
      _combinacoesIndisponiveis = null;
      return precoPadrao;
    }
    
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🔍 COMBINAÇÕES GERADAS (${combinacoes.length})');
    debugPrint('═══════════════════════════════════════════════════════════');
    for (var i = 0; i < combinacoes.length; i++) {
      final combinacao = combinacoes[i];
      debugPrint('Combinação ${i + 1}:');
      debugPrint('  Valores: ${combinacao['valores']}');
      final proporcaoCombinacao = combinacao['proporcao'] as double;
      debugPrint('  Proporção: ${(proporcaoCombinacao * 100).toStringAsFixed(2)}%');
    }
    debugPrint('');
    
    // Soma das combinações proporcionais: cada combinação contribui com seu preço × proporção
    double precoTotal = 0.0;
    int variacoesEncontradas = 0;
    final combinacoesSemVariacao = <Map<String, dynamic>>[];
    
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🔎 BUSCANDO VARIAÇÕES PARA CADA COMBINAÇÃO');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('💡 Cálculo: Soma de (Preço da Variação × Proporção) para cada combinação');
    debugPrint('');
    
    for (var i = 0; i < combinacoes.length; i++) {
      final combinacao = combinacoes[i];
      final proporcao = combinacao['proporcao'] as double;
      debugPrint('\n--- Combinação ${i + 1} ---');
      debugPrint('Valores: ${combinacao['valores']}');
      debugPrint('Proporção: ${(proporcao * 100).toStringAsFixed(2)}%');
      
      final variacao = _encontrarVariacaoParaCombinacao(combinacao['valores'] as Map<String, String>);
      
      if (variacao != null) {
        final precoVariacao = variacao.precoEfetivo;
        if (precoVariacao > 0) {
          // Soma: preço da variação × proporção desta combinação
          final contribuicao = precoVariacao * proporcao;
          precoTotal += contribuicao;
          variacoesEncontradas++;
          debugPrint('  ✅ ENCONTRADA: ${variacao.nomeCompleto}');
          debugPrint('     Preço da Variação: R\$ ${precoVariacao.toStringAsFixed(2)}');
          debugPrint('     Proporção: ${(proporcao * 100).toStringAsFixed(2)}%');
          debugPrint('     Contribuição: R\$ ${contribuicao.toStringAsFixed(2)} (${precoVariacao.toStringAsFixed(2)} × ${proporcao.toStringAsFixed(4)})');
        } else {
          debugPrint('  ⚠️ Variação encontrada mas preço é zero: ${variacao.nomeCompleto}');
          combinacoesSemVariacao.add(Map<String, dynamic>.from(combinacao['valores'] as Map<String, String>));
        }
      } else {
        debugPrint('  ❌ NÃO ENCONTRADA para combinação: ${combinacao['valores']}');
        combinacoesSemVariacao.add(Map<String, dynamic>.from(combinacao['valores'] as Map<String, String>));
      }
    }
    
    debugPrint('\n═══════════════════════════════════════════════════════════');
    debugPrint('📊 RESULTADO DO CÁLCULO');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('Variações encontradas: $variacoesEncontradas de ${combinacoes.length}');
    debugPrint('Preço total (soma das combinações proporcionais): R\$ ${precoTotal.toStringAsFixed(2)}');
    
    // Se alguma combinação não tem variação, marcar como indisponível
    if (combinacoesSemVariacao.isNotEmpty) {
      _combinacoesIndisponiveis = combinacoesSemVariacao;
      debugPrint('❌ Combinações indisponíveis: ${combinacoesSemVariacao.length}');
      for (var comb in combinacoesSemVariacao) {
        debugPrint('   - $comb');
      }
      return null; // Retornar null para indicar que há combinações indisponíveis
    }
    
    // Se não encontrou nenhuma variação válida, retornar null
    if (variacoesEncontradas == 0) {
      debugPrint('⚠️ Nenhuma variação válida encontrada');
      _combinacoesIndisponiveis = combinacoes;
      return null;
    }
    
    // Limpar estado de indisponibilidade se tudo está OK
    _combinacoesIndisponiveis = null;
    
    // Retornar a soma das combinações proporcionais
    debugPrint('✅ Preço final: R\$ ${precoTotal.toStringAsFixed(2)}');
    debugPrint('═══════════════════════════════════════════════════════════\n');
    
    return precoTotal > 0 ? precoTotal : precoPadrao;
  }

  /// Gera todas as combinações possíveis de valores selecionados com suas proporções
  List<Map<String, dynamic>> _gerarCombinacoes() {
    if (_produto == null) return [];
    
    // Preparar lista de valores por atributo com suas proporções
    final valoresPorAtributo = <String, List<Map<String, dynamic>>>{};
    
    for (var atributo in _produto!.atributos) {
      final selecoes = _selecoesAtributos[atributo.id] ?? [];
      if (selecoes.isEmpty) continue;
      
      final valores = <Map<String, dynamic>>[];
      
        if (atributo.permiteSelecaoProporcional) {
        // Usar proporções definidas
          final proporcoes = _proporcoesAtributos[atributo.id] ?? {};
        for (var valorId in selecoes) {
          final proporcao = proporcoes[valorId] ?? (1.0 / selecoes.length);
          valores.add({
            'atributoId': atributo.id,
            'valorId': valorId,
            'proporcao': proporcao,
          });
        }
      } else {
        // Proporção 1.0 (100%) para o único valor selecionado
        valores.add({
          'atributoId': atributo.id,
          'valorId': selecoes.first,
          'proporcao': 1.0,
        });
      }
      
      valoresPorAtributo[atributo.id] = valores;
    }
    
    // Gerar produto cartesiano de todas as combinações
    return _produtoCartesiano(valoresPorAtributo);
  }

  /// Gera produto cartesiano de valores por atributo
  List<Map<String, dynamic>> _produtoCartesiano(Map<String, List<Map<String, dynamic>>> valoresPorAtributo) {
    if (valoresPorAtributo.isEmpty) return [];
    
    final atributosIds = valoresPorAtributo.keys.toList();
    final combinacoes = <Map<String, dynamic>>[];
    
    void gerarCombinacao(int index, Map<String, String> valoresAtuais, double proporcaoAtual) {
      if (index >= atributosIds.length) {
        combinacoes.add({
          'valores': Map<String, String>.from(valoresAtuais),
          'proporcao': proporcaoAtual,
        });
        return;
      }

      final atributoId = atributosIds[index];
      final valores = valoresPorAtributo[atributoId]!;
      
      for (var valor in valores) {
        final novosValores = Map<String, String>.from(valoresAtuais);
        novosValores[atributoId] = valor['valorId'] as String;
        final novaProporcao = proporcaoAtual * (valor['proporcao'] as double);
        
        gerarCombinacao(index + 1, novosValores, novaProporcao);
      }
    }
    
    gerarCombinacao(0, {}, 1.0);
    return combinacoes;
  }

  /// Encontra variação que corresponde a uma combinação específica de valores
  ProdutoVariacaoLocal? _encontrarVariacaoParaCombinacao(Map<String, String> combinacaoValores) {
    if (_produto == null) return null;
    
    debugPrint('  🔍 Buscando variação para combinação:');
    for (var entry in combinacaoValores.entries) {
      final atributoId = entry.key;
      final valorId = entry.value;
      final atributo = _produto!.atributos.firstWhere(
        (a) => a.id == atributoId,
        orElse: () => _produto!.atributos.first,
      );
      final valor = atributo.valores.firstWhere(
        (av) => av.atributoValorId == valorId,
        orElse: () => atributo.valores.first,
      );
      debugPrint('    - ${atributo.nome}: ${valor.nome} (atributoId: $atributoId, valorId: $valorId)');
    }
    
    for (var variacaoIndex = 0; variacaoIndex < _produto!.variacoes.length; variacaoIndex++) {
      final variacao = _produto!.variacoes[variacaoIndex];
      bool corresponde = true;
      final valoresVariacao = <String>[];
      final valoresNaoEncontrados = <String>[];
      
      debugPrint('  Testando variação ${variacaoIndex + 1}: ${variacao.nomeCompleto}');
      debugPrint('    Valores da variação:');
      for (var vv in variacao.valores) {
        debugPrint('      - ${vv.nomeAtributo}: ${vv.nomeValor} (atributoValorId: ${vv.atributoValorId})');
      }
      
      // Verificar se a variação tem todos os valores da combinação
      for (var entry in combinacaoValores.entries) {
        final atributoId = entry.key;
        final valorId = entry.value;
        
        final atributo = _produto!.atributos.firstWhere(
          (a) => a.id == atributoId,
          orElse: () => _produto!.atributos.first,
        );
        
        // Buscar o valor do atributo para comparação
        final valorAtributo = atributo.valores.firstWhere(
          (av) => av.atributoValorId == valorId,
          orElse: () => atributo.valores.first,
        );
        
        debugPrint('    Procurando: ${atributo.nome} = ${valorAtributo.nome} (valorId: $valorId)');
        
        final temValor = variacao.valores.any((vv) {
          // Comparação direta pelo ID
          if (vv.atributoValorId == valorId) {
            valoresVariacao.add('${vv.nomeAtributo}:${vv.nomeValor}');
            debugPrint('      ✅ Encontrado por ID: ${vv.nomeAtributo}:${vv.nomeValor}');
            return true;
          }
          // Comparação pelo nome do atributo e nome do valor
          if (vv.nomeAtributo == atributo.nome && vv.nomeValor == valorAtributo.nome) {
            valoresVariacao.add('${vv.nomeAtributo}:${vv.nomeValor}');
            debugPrint('      ✅ Encontrado por nome: ${vv.nomeAtributo}:${vv.nomeValor}');
            return true;
          }
          return false;
        });
        
        if (!temValor) {
          valoresNaoEncontrados.add('${atributo.nome}:${valorAtributo.nome}');
          debugPrint('      ❌ NÃO encontrado: ${atributo.nome} = ${valorAtributo.nome}');
          corresponde = false;
        }
      }
      
      // Verificar também se a variação não tem valores extras que não estão na combinação
      if (corresponde) {
        if (variacao.valores.length == combinacaoValores.length) {
          debugPrint('    ✅ CORRESPONDE PERFEITAMENTE! (${variacao.valores.length} valores)');
          debugPrint('    Valores correspondentes: $valoresVariacao');
          return variacao;
        } else {
          debugPrint('    ⚠️ Corresponde mas tem quantidade diferente de valores');
          debugPrint('      Variação tem ${variacao.valores.length} valores, combinação tem ${combinacaoValores.length}');
          debugPrint('    Valores correspondentes: $valoresVariacao');
          // Mesmo assim retornar se corresponde
          return variacao;
        }
      } else {
        debugPrint('    ❌ NÃO corresponde');
        if (valoresNaoEncontrados.isNotEmpty) {
          debugPrint('    Valores não encontrados: $valoresNaoEncontrados');
        }
      }
    }
    
    debugPrint('  ❌ Nenhuma variação encontrada para esta combinação');
    return null;
  }

  /// Confirma a seleção
  void _confirmar() async {
    if (!_podeConfirmar()) return;

    final variacao = _obterVariacaoSelecionada();
    final preco = _calcularPrecoComProporcoes();
    
    // Se o preço é null, não pode confirmar (já validado em _podeConfirmar, mas garantia extra)
    if (preco == null) {
      return;
    }
    
    // Construir mapa de proporções se houver atributos proporcionais
    Map<String, double>? proporcoes;
    if (_proporcoesAtributos.isNotEmpty) {
      proporcoes = {};
      for (var entry in _proporcoesAtributos.entries) {
        for (var valorEntry in entry.value.entries) {
          proporcoes[valorEntry.key] = valorEntry.value;
        }
      }
    }

    // Construir mapa de valores de atributos selecionados
    // Map<atributoId, List<valorId>> - valores selecionados para cada atributo
    Map<String, List<String>>? valoresAtributosSelecionados;
    if (_selecoesAtributos.isNotEmpty) {
      valoresAtributosSelecionados = {};
      for (var entry in _selecoesAtributos.entries) {
        if (entry.value.isNotEmpty) {
          valoresAtributosSelecionados[entry.key] = List<String>.from(entry.value);
        }
      }
      // Se ficou vazio após filtrar, definir como null
      if (valoresAtributosSelecionados.isEmpty) {
        valoresAtributosSelecionados = null;
      }
    }

    // Se tem composição removível, abrir modal de personalização
    if (_temComposicaoRemovivelGeral()) {
      final resultadoPersonalizacao = await _abrirModalPersonalizacao(variacao, preco, proporcoes, valoresAtributosSelecionados);
      if (resultadoPersonalizacao != null && mounted) {
        Navigator.of(context).pop(resultadoPersonalizacao);
      }
      return;
    }

    // Caso contrário, criar itens diretamente
    final itens = <ItemProdutoSelecionado>[];
    
    if (_quantidade == 1) {
      // Caso simples: apenas um item
      final componentesRemovidos = _itens.isNotEmpty 
          ? List<String>.from(_itens[0]['componentesRemovidos'] ?? [])
          : <String>[];
      itens.add(ItemProdutoSelecionado(
        produtoId: widget.produtoId,
        produtoNome: widget.produtoNome,
        produtoVariacaoId: variacao?.id,
        produtoVariacaoNome: variacao?.nomeCompleto,
        precoUnitario: preco,
        observacoes: _itens.isNotEmpty ? (_itens[0]['observacoes'] as String?) : null,
        proporcoesAtributos: proporcoes,
        valoresAtributosSelecionados: valoresAtributosSelecionados,
        componentesRemovidos: componentesRemovidos,
      ));
    } else {
      // Múltiplos itens: criar um item para cada entrada na lista
      for (var i = 0; i < _itens.length; i++) {
        final itemData = _itens[i];
        final componentesRemovidos = List<String>.from(itemData['componentesRemovidos'] ?? []);
        // Para múltiplos itens, usar os valores de atributos selecionados (são os mesmos para todos)
        itens.add(ItemProdutoSelecionado(
          produtoId: widget.produtoId,
          produtoNome: widget.produtoNome,
          produtoVariacaoId: itemData['variacaoId'] as String? ?? variacao?.id,
          produtoVariacaoNome: itemData['variacaoNome'] as String? ?? variacao?.nomeCompleto,
          precoUnitario: preco,
          observacoes: itemData['observacoes'] as String?,
          proporcoesAtributos: itemData['proporcoes'] as Map<String, double>? ?? proporcoes,
          valoresAtributosSelecionados: valoresAtributosSelecionados,
          componentesRemovidos: componentesRemovidos,
        ));
      }
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(ProdutoSelecionadoResult(itens: itens));
    }
  }

  /// Abre modal de personalização de itens
  Future<ProdutoSelecionadoResult?> _abrirModalPersonalizacao(
    ProdutoVariacaoLocal? variacao,
    double preco,
    Map<String, double>? proporcoes,
    Map<String, List<String>>? valoresAtributosSelecionados,
  ) async {
    // SEMPRE abre como TELA CHEIA usando PageRouteBuilder
    return await Navigator.of(context, rootNavigator: true).push<ProdutoSelecionadoResult>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => _PersonalizarItensModal(
          produto: _produto!,
          quantidade: _quantidade,
          variacao: variacao,
          preco: preco,
          proporcoes: proporcoes,
          valoresAtributosSelecionados: valoresAtributosSelecionados,
          produtoId: widget.produtoId,
          produtoNome: widget.produtoNome,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        opaque: true,
        fullscreenDialog: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _produto == null
              ? const Center(child: Text('Produto não encontrado'))
              : _buildConteudoPrincipal(),
    );
    
    // SEMPRE retorna Scaffold ocupando TELA CHEIA
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        title: Text(
          widget.produtoNome,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: content,
    );
  }

  Widget _buildConteudoPrincipal() {
    // Conteúdo com imagem e seleções - Layout compacto
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 600;
                            final temVariacoes = _produto!.temVariacoes && _produto!.atributos.isNotEmpty;
                            final temImagem = _produto!.imagemFileName != null && 
                                              _produto!.imagemFileName!.isNotEmpty;
                            
                            // Layout diferente para produtos sem variações
                            if (!temVariacoes) {
                              return SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Imagem maior e centralizada
                                    Center(
                                      child: _buildImagemOuPlaceholder(isWide ? 350 : 280),
                                    ),
                                    const SizedBox(height: 20),
                                    // Informações do produto (descrição, preço, quantidade)
                                    _buildInfoProduto(),
                                  ],
                                ),
                              );
                            }
                            
                            // Layout com variações
                            return Column(
                              children: [
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Imagem do produto (sempre visível, compacta)
                                      if (temImagem && isWide) ...[
                                        Padding(
                                          padding: const EdgeInsets.only(left: 20, top: 20),
                                          child: _buildImagemOuPlaceholder(200),
                                        ),
                                        const SizedBox(width: 20),
                                      ],
                                      // Conteúdo de seleção (com altura limitada e scroll)
                                      Expanded(
                                        child: Column(
                                          children: [
                                            // Cabeçalho compacto mobile: imagem pequena + descrição lado a lado
                                            if (!isWide) ...[
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    // Imagem pequena
                                                    if (temImagem) ...[
                                                      _buildImagemOuPlaceholder(60),
                                                      const SizedBox(width: 12),
                                                    ],
                                                    // Descrição ao lado
                                                    Expanded(
                                                      child: _produto!.descricao != null && _produto!.descricao!.isNotEmpty
                                                          ? Text(
                                                              _produto!.descricao!,
                                                              style: GoogleFonts.plusJakartaSans(
                                                                fontSize: 13,
                                                                color: Colors.grey.shade700,
                                                                height: 1.3,
                                                              ),
                                                              maxLines: 2,
                                                              overflow: TextOverflow.ellipsis,
                                                            )
                                                          : const SizedBox.shrink(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            // Informações do produto (preço, quantidade) - mobile não mostra descrição aqui
                                            _buildInfoProduto(isMobile: !isWide),
                                            // Conteúdo de seleção com altura limitada
                                            Expanded(
                                              child: _buildConteudoCompacto(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
        ),
        // Footer com ações (apenas preço e botão)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Preço ou mensagem de erro
              Expanded(
                child: Builder(
                  builder: (context) {
                    // Verificar primeiro se atributos estão incompletos
                    if (_atributosIncompletos) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selecione os atributos',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          Text(
                            'Complete as seleções',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.orange.shade600,
                            ),
                          ),
                        ],
                      );
                    }
                    
                    // Verificar se há combinações indisponíveis
                    if (_combinacoesIndisponiveis != null && _combinacoesIndisponiveis!.isNotEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Combinação indisponível',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                          Text(
                            'Ajuste as seleções',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      );
                    }
                    
                    // Calcular e exibir preço
                    final preco = _calcularPrecoComProporcoes();
                    if (preco == null) {
                      return Text(
                        'Preço não disponível',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      );
                    }
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'R\$ ${(preco * _quantidade).toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Botão confirmar
              Builder(
                builder: (context) {
                  final podeConfirmar = _podeConfirmar();
                  return ElevatedButton(
                    onPressed: podeConfirmar ? _confirmar : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: podeConfirmar 
                          ? AppTheme.primaryColor 
                          : Colors.grey.shade300,
                      foregroundColor: podeConfirmar 
                          ? Colors.white 
                          : Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Adicionar',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListaItens() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Itens ($_quantidade)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_itens.length, (index) {
              return _buildItemCard(index);
            }),
          ],
        ),
      ),
    );
  }

  /// Verifica se há composição removível em geral (produto ou variação selecionada)
  bool _temComposicaoRemovivelGeral() {
    if (_produto == null) return false;
    
    final variacao = _obterVariacaoSelecionada();
    
    // Verificar composição da variação se houver
    if (variacao != null) {
      final composicaoVariacao = variacao.composicao;
      if (composicaoVariacao.isNotEmpty && composicaoVariacao.any((c) => c.isRemovivel)) {
        return true;
      }
    }
    
    // Verificar composição direta do produto
    final composicaoProduto = _produto!.composicao;
    return composicaoProduto.isNotEmpty && composicaoProduto.any((c) => c.isRemovivel);
  }

  /// Verifica se um item tem composição removível
  bool _temComposicaoRemovivel(int indexItem) {
    final composicao = _obterComposicaoItem(indexItem);
    return composicao.any((c) => c.isRemovivel);
  }

  /// Constrói seção de personalização de itens quando quantidade > 1
  Widget _buildSeccaoPersonalizacaoItens() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Personalizar itens ($_quantidade)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Personalize cada item individualmente removendo componentes da composição:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_itens.length, (index) {
            return _buildCardPersonalizacaoItem(index);
          }),
        ],
      ),
    );
  }

  /// Constrói card de personalização para um item específico
  Widget _buildCardPersonalizacaoItem(int indexItem) {
    final isExpandido = _itensComposicaoExpandidos[indexItem] ?? false;
    final composicao = _obterComposicaoItem(indexItem);
    final composicaoRemovivel = composicao.where((c) => c.isRemovivel).toList();
    
    if (composicaoRemovivel.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _alternarExpansaoComposicaoItem(indexItem),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${indexItem + 1}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Item ${indexItem + 1}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (composicaoRemovivel.any((c) => _isComponenteRemovido(indexItem, c.componenteId)))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Personalizado',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpandido ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          if (isExpandido) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildSeccaoComposicaoItem(indexItem),
            ),
          ],
        ],
      ),
    );
  }

  /// Constrói a seção de composição removível para um item
  Widget _buildSeccaoComposicaoItem(int indexItem) {
    final composicao = _obterComposicaoItem(indexItem);
    final composicaoRemovivel = composicao.where((c) => c.isRemovivel).toList();
    
    if (composicaoRemovivel.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Remover itens',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        ...composicaoRemovivel.map((componente) {
          final isRemovido = _isComponenteRemovido(indexItem, componente.componenteId);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _alternarComponenteRemovido(indexItem, componente.componenteId),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isRemovido ? Colors.red.shade300 : Colors.grey.shade300,
                    width: isRemovido ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isRemovido ? Colors.red.shade50 : Colors.white,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isRemovido ? Colors.red : Colors.grey.shade400,
                          width: 2,
                        ),
                        color: isRemovido ? Colors.red : Colors.transparent,
                      ),
                      child: isRemovido
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        componente.componenteNome,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: isRemovido ? FontWeight.w600 : FontWeight.normal,
                          color: isRemovido ? Colors.red.shade700 : Colors.grey.shade800,
                          decoration: isRemovido ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (isRemovido)
                      Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red.shade400,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildInfoProduto({bool isMobile = false}) {
    final precoUnitario = _calcularPrecoComProporcoes();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome e descrição (apenas no desktop, mobile já mostra no cabeçalho)
          if (!isMobile && _produto!.descricao != null && _produto!.descricao!.isNotEmpty) ...[
            Text(
              _produto!.descricao!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Preço unitário e quantidade na mesma linha
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preço unitário
              if (precoUnitario != null)
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preço unitário',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'R\$ ${precoUnitario.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),
              const SizedBox(width: 16),
              // Controle de quantidade
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quantidade',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _quantidade > 1
                                  ? () => _atualizarQuantidade(_quantidade - 1)
                                  : null,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(10),
                                bottomLeft: Radius.circular(10),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Icon(
                                  Icons.remove,
                                  size: 18,
                                  color: _quantidade > 1 
                                      ? Colors.grey.shade700 
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.symmetric(
                                vertical: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Text(
                              '$_quantidade',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _atualizarQuantidade(_quantidade + 1),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(10),
                                bottomRight: Radius.circular(10),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Icon(
                                  Icons.add,
                                  size: 18,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagemOuPlaceholder(double size) {
    final temImagem = _produto!.imagemFileName != null && 
                      _produto!.imagemFileName!.isNotEmpty;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: temImagem ? Colors.grey.shade100 : Colors.grey.shade50,
        border: temImagem ? null : Border.all(
          color: Colors.grey.shade300,
          width: 2,
          style: BorderStyle.solid,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
              ),
          ],
        ),
      child: temImagem
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                ImageUrlHelper.getOriginalImageUrl(_produto!.imagemFileName) ?? '',
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholderSemImagem(size);
                },
              ),
            )
          : _buildPlaceholderSemImagem(size),
    );
  }

  Widget _buildPlaceholderSemImagem(double size) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey.shade50,
      ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
            _produto!.tipoRepresentacaoEnum == TipoRepresentacaoVisual.imagem
                ? Icons.image_not_supported_outlined
                : Icons.inventory_2_outlined,
            size: size * 0.25,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Produto sem foto',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            ),
          ],
        ),
      );
    }

  /// Layout compacto com tabs horizontais para navegar entre atributos
  Widget _buildConteudoCompacto() {
    if (_produto == null) return const SizedBox.shrink();
    
    // Se não tem variações, apenas quantidade
    if (!_produto!.temVariacoes || _produto!.atributos.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Ordenar atributos por ordem
    final atributosOrdenados = List<ProdutoAtributoLocal>.from(_produto!.atributos)
      ..sort((a, b) => a.ordem.compareTo(b.ordem));
    
    if (atributosOrdenados.isEmpty) {
      return const Center(
        child: Text('Nenhum atributo disponível'),
      );
    }
    
    // Garantir que o índice está válido
    if (_atributoAtualIndex >= atributosOrdenados.length) {
      _atributoAtualIndex = 0;
    }
    
    final atributoAtual = atributosOrdenados[_atributoAtualIndex];
    final valoresDisponiveis = _obterValoresDisponiveis(atributoAtual);
    final selecoes = _selecoesAtributos[atributoAtual.id] ?? [];
    final isCompleto = _atributoCompleto(atributoAtual);
    
    return Column(
      children: [
        // Tabs horizontais para navegar entre atributos
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: atributosOrdenados.length,
            itemBuilder: (context, index) {
              final atributo = atributosOrdenados[index];
              final isSelected = index == _atributoAtualIndex;
              final isCompletoAtributo = _atributoCompleto(atributo);
              final selecoesAtributo = _selecoesAtributos[atributo.id] ?? [];
              
              // Obter nomes dos valores selecionados
              String? valoresSelecionadosTexto;
              if (selecoesAtributo.isNotEmpty) {
                final nomesValores = selecoesAtributo.map((valorId) {
                  try {
                    final valor = atributo.valores.firstWhere(
                      (v) => v.atributoValorId == valorId,
                    );
                    return valor.nome;
                  } catch (e) {
                    return null;
                  }
                }).where((nome) => nome != null).cast<String>().toList();
                
                if (nomesValores.isNotEmpty) {
                  valoresSelecionadosTexto = nomesValores.length > 1
                      ? '${nomesValores.first} +${nomesValores.length - 1}'
                      : nomesValores.first;
                }
              }
              
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => setState(() => _atributoAtualIndex = index),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppTheme.primaryColor 
                          : (isCompletoAtributo 
                              ? AppTheme.successColor.withOpacity(0.1)
                              : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected 
                            ? AppTheme.primaryColor 
                            : (isCompletoAtributo 
                                ? AppTheme.successColor.withOpacity(0.5)
                                : Colors.grey.shade300),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              atributo.nome,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected 
                                    ? Colors.white 
                                    : (isCompletoAtributo 
                                        ? Colors.grey.shade800 // Mesma cor do valor selecionado para contraste
                                        : Colors.black87),
                              ),
                            ),
                            if (valoresSelecionadosTexto != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                ': $valoresSelecionadosTexto',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected 
                                      ? Colors.white.withOpacity(0.95)
                                      : Colors.grey.shade800, // Cor escura para melhor contraste
                                ),
                              ),
                            ],
                            if (isCompletoAtributo) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: isSelected ? Colors.white : AppTheme.successColor,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        // Conteúdo do atributo atual com scroll limitado
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info de seleção proporcional (se houver)
                      if (atributoAtual.permiteSelecaoProporcional) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 12,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Selecione um ou mais valores',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      // Grid de valores disponíveis (2-3 colunas)
                      valoresDisponiveis.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text(
                                  'Nenhum valor disponível para este atributo',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final crossAxisCount = constraints.maxWidth > 400 ? 3 : 2;
                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: 3.5,
                                  ),
                                  itemCount: valoresDisponiveis.length,
                                  itemBuilder: (context, index) {
                                    final valor = valoresDisponiveis[index];
                                    final isSelected = selecoes.contains(valor.atributoValorId);
                                    return _buildValorChipCompacto(atributoAtual, valor, isSelected);
                                  },
                                );
                              },
                            ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              // Área fixa de proporções (para todos os atributos proporcionais)
              _buildAreaProporcoesFixa(atributosOrdenados),
            ],
          ),
        ),
      ],
    );
  }

  /// Card de item individual (quando quantidade > 1)
  Widget _buildItemCard(int index) {
    final item = _itens[index];
    final isExpandido = _itensExpandidos[index] ?? false;
    final observacoes = item['observacoes'] as String? ?? '';
    final variacao = _obterVariacaoSelecionada();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do item
          InkWell(
            onTap: () => _alternarExpansaoItem(index),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Número do item
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Informações do item
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.produtoNome,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (variacao != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            variacao.nomeCompleto,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                        if (observacoes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            observacoes,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Botão remover (se tiver mais de 1 item)
                  if (_quantidade > 1)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Colors.red.shade400,
                      onPressed: () => _removerItem(index),
                    ),
                  // Ícone expandir/recolher
                  Icon(
                    isExpandido ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          // Conteúdo expandido (campo de observações e composição)
          if (isExpandido) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Seção de observações
                  Text(
                    'Observações',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Ex: Sem cebola, sem batata palha, bem passado...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    controller: TextEditingController(text: observacoes)
                      ..selection = TextSelection.collapsed(offset: observacoes.length),
                    onChanged: (value) => _atualizarObservacoesItem(index, value),
                  ),
                  // Seção de composição removível
                  if (_temComposicaoRemovivel(index)) ...[
                    const SizedBox(height: 24),
                    _buildSeccaoComposicaoItem(index),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConteudo() {
    // Se não tem variações, apenas quantidade
    if (!_produto!.temVariacoes || _produto!.atributos.isEmpty) {
      return const SizedBox.shrink();
    }

    // Ordenar atributos por ordem
    final atributosOrdenados = List<ProdutoAtributoLocal>.from(_produto!.atributos)
      ..sort((a, b) => a.ordem.compareTo(b.ordem));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lista de todos os atributos navegáveis
        ...atributosOrdenados.map((atributo) {
          final isExpandido = _atributosExpandidos[atributo.id] ?? false;
          final isCompleto = _atributoCompleto(atributo);
          final valoresDisponiveis = _obterValoresDisponiveis(atributo);
          final selecoes = _selecoesAtributos[atributo.id] ?? [];

    return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: isCompleto ? AppTheme.successColor.withOpacity(0.3) : Colors.grey.shade300,
                width: isCompleto ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: isCompleto ? AppTheme.successColor.withOpacity(0.05) : Colors.white,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                // Header do atributo (sempre visível)
                InkWell(
                  onTap: () => _alternarExpansao(atributo.id),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
          Row(
            children: [
              Text(
                atributo.nome,
                style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
                                  if (isCompleto) ...[
                const SizedBox(width: 8),
                                    Icon(
                                      Icons.check_circle,
                                      size: 20,
                                      color: AppTheme.successColor,
                ),
              ],
            ],
          ),
          if (atributo.descricao != null) ...[
            const SizedBox(height: 4),
            Text(
              atributo.descricao!,
              style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
              ),
            ),
          ],
                              if (atributo.permiteSelecaoProporcional) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 4),
            Text(
                                      'Selecione um ou mais valores',
              style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: AppTheme.primaryColor,
                fontStyle: FontStyle.italic,
              ),
                                    ),
                                  ],
                                ),
                              ],
                              if (selecoes.isNotEmpty) ...[
                                const SizedBox(height: 8),
            Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: selecoes.map((valorId) {
                                    final valor = atributo.valores.firstWhere(
                                      (v) => v.atributoValorId == valorId,
                                      orElse: () => atributo.valores.first,
                                    );
                                    return Chip(
                                      label: Text(valor.nome),
                                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                      labelStyle: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    );
                                  }).toList(),
                                ),
          ],
        ],
      ),
                        ),
                        Icon(
                          isExpandido ? Icons.expand_less : Icons.expand_more,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),
                // Conteúdo expandido
                if (isExpandido) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: valoresDisponiveis.isEmpty
                        ? Text(
                            'Nenhum valor disponível para este atributo',
              style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Valores disponíveis
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: valoresDisponiveis.map((valor) {
                                  final isSelected = selecoes.contains(valor.atributoValorId);
                                  return _buildValorChip(atributo, valor, isSelected);
                                }).toList(),
                              ),
                              // Proporções se permitir seleção proporcional (sempre mostrar quando houver seleções)
                              if (atributo.permiteSelecaoProporcional && selecoes.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                Text(
                                  'Proporções',
              style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
                                ),
                                const SizedBox(height: 12),
                                ...selecoes.map((valorId) {
                                  final valor = atributo.valores.firstWhere((v) => v.atributoValorId == valorId);
                                  // Se só tem uma seleção, proporção é 100%, senão pega do mapa
                                  final proporcao = selecoes.length == 1 
                                      ? 1.0 
                                      : (_proporcoesAtributos[atributo.id]?[valorId] ?? (1.0 / selecoes.length));
                                  return _buildProporcaoInput(atributo, valor, proporcao);
                                }),
                              ],
                            ],
                          ),
                  ),
                ],
        ],
      ),
    );
        }).toList(),
        // Mensagem quando atributos não estão completos
        if (!_produto!.atributos.every((a) => _atributoCompleto(a))) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecione os atributos',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Complete todas as seleções para ver o preço',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        // Resumo final se todos estiverem completos
        if (_produto!.atributos.every((a) => _atributoCompleto(a))) ...[
          const SizedBox(height: 16),
          // Mensagem de erro se há combinações indisponíveis
          if (_combinacoesIndisponiveis != null && _combinacoesIndisponiveis!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Combinação indisponível',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Algumas combinações selecionadas não possuem variação cadastrada. Ajuste as seleções para continuar.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Mensagem de sucesso se tudo está OK
          if (_combinacoesIndisponiveis == null || _combinacoesIndisponiveis!.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.successColor.withOpacity(0.3),
              ),
        ),
        child: Row(
          children: [
                Icon(Icons.check_circle, color: AppTheme.successColor),
            const SizedBox(width: 12),
            Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                        'Seleção completa',
              style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                fontWeight: FontWeight.w600,
                          color: AppTheme.successColor,
                        ),
                      ),
                      if (_obterVariacaoSelecionada() != null) ...[
              const SizedBox(height: 4),
              Text(
                          'Variação: ${_obterVariacaoSelecionada()!.nomeCompleto}',
                style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildValorChip(
    ProdutoAtributoLocal atributo,
    ProdutoAtributoValorLocal valor,
    bool isSelected,
  ) {
    return FilterChip(
      label: Text(valor.nome),
      selected: isSelected,
      onSelected: (selected) => _selecionarValor(atributo, valor),
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: GoogleFonts.plusJakartaSans(
        color: isSelected ? AppTheme.primaryColor : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  /// Área fixa de proporções com resumo e expansão
  Widget _buildAreaProporcoesFixa(List<ProdutoAtributoLocal> atributosOrdenados) {
    // Filtrar apenas atributos proporcionais com seleções
    final atributosProporcionais = atributosOrdenados.where((atributo) {
      if (!atributo.permiteSelecaoProporcional) return false;
      final selecoes = _selecoesAtributos[atributo.id] ?? [];
      return selecoes.isNotEmpty;
    }).toList();

    if (atributosProporcionais.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: atributosProporcionais.map((atributo) {
          final selecoes = _selecoesAtributos[atributo.id] ?? [];
          final isExpandido = _proporcoesExpandidas[atributo.id] ?? false;
          
          return _buildProporcoesCard(atributo, selecoes, isExpandido);
        }).toList(),
      ),
    );
  }

  /// Card de proporções com resumo e expansão
  Widget _buildProporcoesCard(
    ProdutoAtributoLocal atributo,
    List<String> selecoes,
    bool isExpandido,
  ) {
    // Calcular proporções
    final proporcoes = <String, double>{};
    for (var valorId in selecoes) {
      proporcoes[valorId] = selecoes.length == 1
          ? 1.0
          : (_proporcoesAtributos[atributo.id]?[valorId] ?? (1.0 / selecoes.length));
    }

    // Criar resumo
    final resumo = selecoes.map((valorId) {
      final valor = atributo.valores.firstWhere(
        (v) => v.atributoValorId == valorId,
        orElse: () => atributo.valores.first,
      );
      final proporcao = proporcoes[valorId] ?? 0.0;
      return '${valor.nome}: ${(proporcao * 100).toStringAsFixed(0)}%';
    }).join(' • ');

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header clicável com resumo
          InkWell(
            onTap: () {
              setState(() {
                _proporcoesExpandidas[atributo.id] = !isExpandido;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.percent,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Proporções: ${atributo.nome}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          resumo,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpandido ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          // Conteúdo expandido para edição
          if (isExpandido) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...selecoes.map((valorId) {
                    final valor = atributo.valores.firstWhere(
                      (v) => v.atributoValorId == valorId,
                      orElse: () => atributo.valores.first,
                    );
                    final proporcao = proporcoes[valorId] ?? 0.0;
                    return _buildProporcaoInput(atributo, valor, proporcao);
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Chip compacto para grid
  Widget _buildValorChipCompacto(
    ProdutoAtributoLocal atributo,
    ProdutoAtributoValorLocal valor,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () => _selecionarValor(atributo, valor),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor.withOpacity(0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected 
                ? AppTheme.primaryColor 
                : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  valor.nome,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? AppTheme.primaryColor : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProporcaoInput(
    ProdutoAtributoLocal atributo,
    ProdutoAtributoValorLocal valor,
    double proporcao,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
            child: Text(
              valor.nome,
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
            ),
          ),
          SizedBox(
            width: 100,
            child: TextField(
              controller: TextEditingController(
                text: (proporcao * 100).toStringAsFixed(0),
              ),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                suffixText: '%',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (value) {
                final percent = double.tryParse(value) ?? 0.0;
                final novaProporcao = percent / 100.0;
                _atualizarProporcao(atributo, valor.atributoValorId, novaProporcao);
                _normalizarProporcoes(atributo.id);
              },
                      ),
                    ),
                  ],
      ),
    );
  }
}

/// Modal para personalizar itens individuais quando quantidade > 1
class _PersonalizarItensModal extends StatefulWidget {
  final ProdutoLocal produto;
  final int quantidade;
  final ProdutoVariacaoLocal? variacao;
  final double preco;
  final Map<String, double>? proporcoes;
  final Map<String, List<String>>? valoresAtributosSelecionados;
  final String produtoId;
  final String produtoNome;

  const _PersonalizarItensModal({
    required this.produto,
    required this.quantidade,
    this.variacao,
    required this.preco,
    this.proporcoes,
    this.valoresAtributosSelecionados,
    required this.produtoId,
    required this.produtoNome,
  });

  @override
  State<_PersonalizarItensModal> createState() => _PersonalizarItensModalState();
}

class _PersonalizarItensModalState extends State<_PersonalizarItensModal> {
  final List<Map<String, dynamic>> _itens = [];
  final Map<int, bool> _itensExpandidos = {};
  final Map<int, TextEditingController> _observacaoControllers = {};

  @override
  void initState() {
    super.initState();
    _inicializarItens();
  }

  @override
  void dispose() {
    // Limpar controllers
    for (var controller in _observacaoControllers.values) {
      controller.dispose();
    }
    _observacaoControllers.clear();
    super.dispose();
  }

  void _inicializarItens() {
    _itens.clear();
    // Limpar controllers antigos
    for (var controller in _observacaoControllers.values) {
      controller.dispose();
    }
    _observacaoControllers.clear();
    
    for (int i = 0; i < widget.quantidade; i++) {
      final observacaoInicial = '';
      _itens.add({
        'componentesRemovidos': <String>[],
        'observacao': observacaoInicial,
      });
      // Criar controller para cada item com valor inicial
      _observacaoControllers[i] = TextEditingController(text: observacaoInicial);
    }
  }

  List<ProdutoComposicaoLocal> _obterComposicao() {
    if (widget.variacao != null) {
      return widget.variacao!.composicao.isNotEmpty ? widget.variacao!.composicao : [];
    }
    return widget.produto.composicao.isNotEmpty ? widget.produto.composicao : [];
  }

  List<ProdutoComposicaoLocal> _obterComposicaoRemovivel() {
    return _obterComposicao().where((c) => c.isRemovivel).toList();
  }

  void _alternarComponenteRemovido(int indexItem, String componenteId) {
    setState(() {
      final componentesRemovidos = List<String>.from(_itens[indexItem]['componentesRemovidos'] ?? []);
      if (componentesRemovidos.contains(componenteId)) {
        componentesRemovidos.remove(componenteId);
      } else {
        componentesRemovidos.add(componenteId);
      }
      _itens[indexItem]['componentesRemovidos'] = componentesRemovidos;
    });
  }

  bool _isComponenteRemovido(int indexItem, String componenteId) {
    final componentesRemovidos = _itens[indexItem]['componentesRemovidos'] as List<String>? ?? [];
    return componentesRemovidos.contains(componenteId);
  }

  void _alternarExpansaoItem(int index) {
    setState(() {
      _itensExpandidos[index] = !(_itensExpandidos[index] ?? false);
    });
  }

  void _confirmar() {
    final composicaoRemovivel = _obterComposicaoRemovivel();
    if (composicaoRemovivel.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final itens = <ItemProdutoSelecionado>[];
    for (var i = 0; i < _itens.length; i++) {
      final itemData = _itens[i];
      final componentesRemovidos = List<String>.from(itemData['componentesRemovidos'] ?? []);
      final observacao = itemData['observacao'] as String? ?? '';
      itens.add(ItemProdutoSelecionado(
        produtoId: widget.produtoId,
        produtoNome: widget.produtoNome,
        produtoVariacaoId: widget.variacao?.id,
        produtoVariacaoNome: widget.variacao?.nomeCompleto,
        precoUnitario: widget.preco,
        proporcoesAtributos: widget.proporcoes,
        valoresAtributosSelecionados: widget.valoresAtributosSelecionados,
        componentesRemovidos: componentesRemovidos,
        observacoes: observacao.isNotEmpty ? observacao : null,
      ));
    }

    Navigator.of(context, rootNavigator: true).pop(ProdutoSelecionadoResult(itens: itens));
  }

  @override
  Widget build(BuildContext context) {
    final composicaoRemovivel = _obterComposicaoRemovivel();

    // SEMPRE retorna Scaffold ocupando TELA CHEIA
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Personalizar itens',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              '${widget.produtoNome} (${widget.quantidade} ${widget.quantidade == 1 ? 'item' : 'itens'})',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Conteúdo
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remova componentes de cada item conforme necessário:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(_itens.length, (index) {
                    return _buildItemCard(index, composicaoRemovivel);
                  }),
                ],
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _confirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text('Confirmar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index, List<ProdutoComposicaoLocal> composicaoRemovivel) {
    final isExpandido = _itensExpandidos[index] ?? false;
    final componentesRemovidos = _itens[index]['componentesRemovidos'] as List<String>? ?? [];
    final observacao = _itens[index]['observacao'] as String? ?? '';
    final temPersonalizacao = componentesRemovidos.isNotEmpty || observacao.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: temPersonalizacao ? Colors.orange.shade300 : Colors.grey.shade300,
          width: temPersonalizacao ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: temPersonalizacao ? Colors.orange.shade50 : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do item
          InkWell(
            onTap: () => _alternarExpansaoItem(index),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Item ${index + 1}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (temPersonalizacao)
                    Row(
                      children: [
                        if (componentesRemovidos.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${componentesRemovidos.length} removido${componentesRemovidos.length == 1 ? '' : 's'}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        if (observacao.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.note,
                                  size: 12,
                                  color: Colors.blue.shade900,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Obs',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpandido ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          // Conteúdo expandido
          if (isExpandido) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remover componentes',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...composicaoRemovivel.map((componente) {
                    final isRemovido = _isComponenteRemovido(index, componente.componenteId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _alternarComponenteRemovido(index, componente.componenteId),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isRemovido ? Colors.red.shade300 : Colors.grey.shade300,
                              width: isRemovido ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: isRemovido ? Colors.red.shade50 : Colors.white,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isRemovido ? Colors.red : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                  color: isRemovido ? Colors.red : Colors.transparent,
                                ),
                                child: isRemovido
                                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  componente.componenteNome,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: isRemovido ? FontWeight.w600 : FontWeight.normal,
                                    color: isRemovido ? Colors.red.shade700 : Colors.grey.shade800,
                                    decoration: isRemovido ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                              if (isRemovido)
                                Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red.shade400,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                  // Campo de observação
                  Text(
                    'Observação',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _observacaoControllers[index],
                    onChanged: (value) {
                      setState(() {
                        _itens[index]['observacao'] = value;
                      });
                    },
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Digite observações para este item...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
                  ],
      ),
    );
  }
}
