import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../models/core/api_response.dart';
import '../../models/sync/produto_pdv_sync_dto.dart';
import '../../models/sync/exibicao_produto_pdv_sync_dto.dart';
import '../../repositories/produto_local_repository.dart';
import '../../repositories/exibicao_produto_local_repository.dart';
import '../../repositories/pedido_local_repository.dart';
import '../../models/local/pedido_local.dart';
import '../../models/local/sync_status_pedido.dart';
import '../../models/local/produto_composicao_local.dart';
import '../../services/core/pedido_service.dart';
import '../../models/core/pedido_list_item.dart';
import '../../services/modules/restaurante/configuracao_restaurante_service.dart';
import 'package:uuid/uuid.dart';

/// Resultado de sincronização
class SyncResult {
  final bool sucesso;
  final String? erro;
  final int produtosSincronizados;
  final int gruposSincronizados;
  final int pedidosSincronizados;
  final int pedidosComErro;

  SyncResult({
    required this.sucesso,
    this.erro,
    this.produtosSincronizados = 0,
    this.gruposSincronizados = 0,
    this.pedidosSincronizados = 0,
    this.pedidosComErro = 0,
  });
}

/// Progresso de sincronização
class SyncProgress {
  final String etapa;
  final int progresso; // 0-100
  final String mensagem;
  final int progressoGeral; // 0-100 (progresso geral de todas as etapas)

  SyncProgress({
    required this.etapa,
    required this.progresso,
    required this.mensagem,
    this.progressoGeral = 0,
  });
}

/// Exceção de sincronização
class SyncException implements Exception {
  final String message;
  SyncException(this.message);

  @override
  String toString() => 'SyncException: $message';
}

/// Serviço principal de sincronização
class SyncService {
  final ApiClient _apiClient;
  final ProdutoLocalRepository _produtoRepo;
  final ExibicaoProdutoLocalRepository _exibicaoRepo;
  final PedidoLocalRepository _pedidoRepo;
  final PedidoService _pedidoService;
  final ConfiguracaoRestauranteService? _configuracaoRestauranteService;

  bool _isSyncing = false;
  
  // Controle de pedidos sendo sincronizados para evitar duplicação
  final Set<String> _pedidosSincronizando = {};

  SyncService({
    required ApiClient apiClient,
    required ProdutoLocalRepository produtoRepo,
    required ExibicaoProdutoLocalRepository exibicaoRepo,
    required PedidoLocalRepository pedidoRepo,
    required PedidoService pedidoService,
    ConfiguracaoRestauranteService? configuracaoRestauranteService,
  })  : _apiClient = apiClient,
        _produtoRepo = produtoRepo,
        _exibicaoRepo = exibicaoRepo,
        _pedidoRepo = pedidoRepo,
        _pedidoService = pedidoService,
        _configuracaoRestauranteService = configuracaoRestauranteService;

  /// Inicia sincronização completa
  Future<SyncResult> sincronizarCompleto({
    Function(SyncProgress)? onProgress,
    bool forcar = false,
  }) async {
    if (_isSyncing) {
      throw SyncException('Sincronização já em andamento');
    }

    _isSyncing = true;
    try {
      // 1. Sincronizar produtos (0-50% do progresso geral)
      onProgress?.call(SyncProgress(
        etapa: 'Produtos',
        progresso: 0,
        mensagem: 'Sincronizando produtos...',
        progressoGeral: 0,
      ));
      
      final produtosResult = await _sincronizarProdutos(
        onProgress: (progress) {
          // Progresso da etapa produtos (0-100%) mapeado para 0-50% do geral
          onProgress?.call(SyncProgress(
            etapa: progress.etapa,
            progresso: progress.progresso,
            mensagem: progress.mensagem,
            progressoGeral: (progress.progresso * 0.5).round(),
          ));
        },
      );

      // 2. Sincronizar grupos de exibição (50-100% do progresso geral)
      onProgress?.call(SyncProgress(
        etapa: 'Grupos de Exibição',
        progresso: 0,
        mensagem: 'Sincronizando grupos...',
        progressoGeral: 50,
      ));
      
      final gruposResult = await _sincronizarGruposExibicao(
        onProgress: (progress) {
          // Progresso da etapa grupos (0-100%) mapeado para 50-100% do geral
          onProgress?.call(SyncProgress(
            etapa: progress.etapa,
            progresso: progress.progresso,
            mensagem: progress.mensagem,
            progressoGeral: 50 + (progress.progresso * 0.5).round(),
          ));
        },
      );

      // 3. Sincronizar pedidos pendentes
      onProgress?.call(SyncProgress(
        etapa: 'Pedidos',
        progresso: 0,
        mensagem: 'Sincronizando pedidos...',
        progressoGeral: 100,
      ));
      
      final pedidosResult = await _sincronizarPedidos(
        onProgress: (progress) {
          onProgress?.call(SyncProgress(
            etapa: progress.etapa,
            progresso: progress.progresso,
            mensagem: progress.mensagem,
            progressoGeral: 100, // Pedidos são rápidos, mantém em 100%
          ));
        },
      );

      onProgress?.call(SyncProgress(
        etapa: 'Concluído',
        progresso: 100,
        mensagem: 'Sincronização concluída',
        progressoGeral: 100,
      ));

      return SyncResult(
        sucesso: true,
        produtosSincronizados: produtosResult.total,
        gruposSincronizados: gruposResult.total,
        pedidosSincronizados: pedidosResult.sincronizados,
        pedidosComErro: pedidosResult.erros,
      );
    } catch (e) {
      debugPrint('Erro na sincronização: $e');
      return SyncResult(
        sucesso: false,
        erro: e.toString(),
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Sincroniza apenas produtos (com paginação)
  Future<({int total, String? erro})> _sincronizarProdutos({
    Function(SyncProgress)? onProgress,
  }) async {
    const pageSize = 10;
    int page = 1;
    final todosProdutos = <ProdutoPdvSyncDto>[];

    try {
      // Inicia sincronização de produtos
      onProgress?.call(SyncProgress(
        etapa: 'Produtos',
        progresso: 0,
        mensagem: 'Buscando produtos...',
      ));

      var hasMore = true;
      int totalPages = 1;
      
      while (hasMore) {
        // Buscar página da API
        final response = await _apiClient.get<Map<String, dynamic>>(
          ApiEndpoints.syncProdutos,
          queryParameters: {
            'page': page,
            'pageSize': pageSize,
          },
        );

        if (response.data == null) {
          throw SyncException('Resposta vazia da API');
        }

        // Parse da resposta paginada
        final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
          response.data!,
          (data) => data as Map<String, dynamic>? ?? {},
        );

        if (!apiResponse.success || apiResponse.data == null) {
          throw SyncException('Erro ao buscar produtos: ${apiResponse.message}');
        }

        // Parse da estrutura paginada
        final paginatedData = apiResponse.data!;
        final listData = paginatedData['list'] as List<dynamic>? ?? [];
        final paginationData = paginatedData['pagination'] as Map<String, dynamic>? ?? {};
        
        totalPages = paginationData['totalPages'] as int? ?? 1;

        // Converter produtos da página atual
        for (var json in listData) {
          try {
            final jsonMap = json as Map<String, dynamic>;
            final produtoNome = jsonMap['nome'] as String? ?? 'Desconhecido';
            
            // DEBUG: Verificar JSON bruto antes da conversão - SEMPRE mostrar
            debugPrint('═══════════════════════════════════════════════════════════');
            debugPrint('🔍 JSON BRUTO - Produto: $produtoNome');
            debugPrint('═══════════════════════════════════════════════════════════');
            
            // DEBUG: Verificar composição do produto
            if (jsonMap.containsKey('composicao')) {
              final composicaoJson = jsonMap['composicao'] as List<dynamic>? ?? [];
              debugPrint('📋 Composição do produto no JSON: ${composicaoJson.length} itens');
              for (var i = 0; i < composicaoJson.length; i++) {
                final compJson = composicaoJson[i] as Map<String, dynamic>;
                debugPrint('  Item ${i + 1}: ${compJson['componenteNome']} (ID: ${compJson['componenteId']}, Removível: ${compJson['isRemovivel']})');
              }
            } else {
              debugPrint('  ⚠️ Produto $produtoNome não tem chave "composicao" no JSON!');
            }
            
            if (jsonMap.containsKey('variacoes')) {
              final variacoesJson = jsonMap['variacoes'] as List<dynamic>? ?? [];
              debugPrint('Variações no JSON: ${variacoesJson.length}');
              
              for (var i = 0; i < variacoesJson.length; i++) {
                final variacaoJson = variacoesJson[i] as Map<String, dynamic>;
                final variacaoNome = variacaoJson['nomeCompleto'] as String? ?? 'Sem nome';
                final valoresJson = variacaoJson['valores'] as List<dynamic>? ?? [];
                
                // DEBUG: Verificar composição da variação
                if (variacaoJson.containsKey('composicao')) {
                  final composicaoVarJson = variacaoJson['composicao'] as List<dynamic>? ?? [];
                  debugPrint('  📋 Composição da variação "$variacaoNome": ${composicaoVarJson.length} itens');
                  for (var j = 0; j < composicaoVarJson.length; j++) {
                    final compJson = composicaoVarJson[j] as Map<String, dynamic>;
                    debugPrint('    Item ${j + 1}: ${compJson['componenteNome']} (ID: ${compJson['componenteId']}, Removível: ${compJson['isRemovivel']})');
                  }
                } else {
                  debugPrint('  ⚠️ Variação "$variacaoNome" não tem chave "composicao" no JSON!');
                }
                
                debugPrint('  Variação ${i + 1}: $variacaoNome');
                debugPrint('    Valores no JSON: ${valoresJson.length}');
                
                if (valoresJson.isEmpty) {
                  debugPrint('    ⚠️⚠️⚠️ ATENÇÃO: Variação não tem valores no JSON bruto!');
                  debugPrint('    Chaves da variação: ${variacaoJson.keys.toList()}');
                  debugPrint('    Conteúdo completo da variação: $variacaoJson');
                } else {
                  debugPrint('    ✅ Valores encontrados no JSON:');
                  for (var j = 0; j < valoresJson.length; j++) {
                    final valorJson = valoresJson[j] as Map<String, dynamic>;
                    debugPrint('      Valor ${j + 1}: ${valorJson['nomeAtributo']} = ${valorJson['nomeValor']} (id: ${valorJson['id']}, atributoValorId: ${valorJson['atributoValorId']})');
                  }
                }
              }
            } else {
              debugPrint('  ⚠️ Produto $produtoNome não tem chave "variacoes" no JSON!');
              debugPrint('  Chaves disponíveis: ${jsonMap.keys.toList()}');
            }
            
            final produto = ProdutoPdvSyncDto.fromJson(jsonMap);
            todosProdutos.add(produto);
            
            // DEBUG: Verificar valores das variações após conversão
            debugPrint('📦 Produto convertido: ${produto.nome} - ${produto.variacoes.length} variações');
            debugPrint('📋 Composição do produto após conversão: ${produto.composicao.length} itens');
            for (var comp in produto.composicao) {
              debugPrint('  - ${comp.componenteNome} (ID: ${comp.componenteId}, Removível: ${comp.isRemovivel})');
            }
            for (var variacao in produto.variacoes) {
              debugPrint('  Variação: ${variacao.nomeCompleto} - ${variacao.valores.length} valores');
              debugPrint('    📋 Composição da variação: ${variacao.composicao.length} itens');
              for (var comp in variacao.composicao) {
                debugPrint('      - ${comp.componenteNome} (ID: ${comp.componenteId}, Removível: ${comp.isRemovivel})');
              }
              if (variacao.valores.isEmpty) {
                debugPrint('    ⚠️⚠️⚠️ ATENÇÃO: Variação não tem valores após conversão!');
              } else {
                for (var valor in variacao.valores) {
                  debugPrint('    Valor: ${valor.nomeAtributo} = ${valor.nomeValor} (atributoValorId: ${valor.atributoValorId})');
                }
              }
            }
            debugPrint('═══════════════════════════════════════════════════════════\n');
          } catch (e, stackTrace) {
            debugPrint('Erro ao converter produto: $e');
            debugPrint('Stack trace: $stackTrace');
            debugPrint('JSON: $json');
            // Continua processando outros produtos mesmo se um falhar
          }
        }

        // Atualizar progresso (0-100% da etapa produtos)
        final progressoEtapa = ((page / totalPages) * 100).round();
        onProgress?.call(SyncProgress(
          etapa: 'Produtos',
          progresso: progressoEtapa,
          mensagem: 'Buscando produtos...',
        ));

        // Verificar se há mais páginas
        hasMore = page < totalPages;
        if (hasMore) {
          page++;
        }
      }

      onProgress?.call(SyncProgress(
        etapa: 'Produtos',
        progresso: 80,
        mensagem: 'Salvando produtos...',
      ));

      // Garantir que o repositório está inicializado
      await _produtoRepo.init();

      // Salvar localmente (substituir todos)
      // O método salvarTodos já limpa o box antes de salvar
      await _produtoRepo.salvarTodos(todosProdutos);

      // Atualizar metadados
      await _atualizarMetadadosSincronizacao('produtos', DateTime.now());

      onProgress?.call(SyncProgress(
        etapa: 'Produtos',
        progresso: 100,
        mensagem: 'Produtos sincronizados',
      ));

      return (total: todosProdutos.length, erro: null);
    } catch (e) {
      debugPrint('Erro ao sincronizar produtos: $e');
      return (total: todosProdutos.length, erro: e.toString());
    }
  }

  /// Sincroniza grupos de exibição
  Future<({int total, String? erro})> _sincronizarGruposExibicao({
    Function(SyncProgress)? onProgress,
  }) async {
    onProgress?.call(SyncProgress(
      etapa: 'Grupos de Exibição',
      progresso: 0,
      mensagem: 'Buscando grupos de exibição...',
    ));

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.syncGruposExibicao,
      );

      if (response.data == null) {
        throw SyncException('Resposta vazia da API');
      }

      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data!,
        (data) => data is List ? data : [],
      );

      if (!apiResponse.success || apiResponse.data == null) {
        throw SyncException('Erro ao buscar grupos: ${apiResponse.message}');
      }

      debugPrint('📦 DEBUG: Resposta da API recebida: ${apiResponse.data?.length ?? 0} grupos');

      final gruposDto = apiResponse.data!
          .map((json) {
            try {
              return ExibicaoProdutoPdvSyncDto.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              debugPrint('❌ Erro ao converter grupo: $e');
              debugPrint('JSON: $json');
              rethrow;
            }
          })
          .toList();

      debugPrint('📦 DEBUG: ${gruposDto.length} grupos convertidos com sucesso');
      for (var grupo in gruposDto) {
        debugPrint('  - ${grupo.nome} (ID: ${grupo.id}): ${grupo.produtos.length} produtos, ${grupo.categoriasFilhas.length} categorias filhas');
      }

      onProgress?.call(SyncProgress(
        etapa: 'Grupos de Exibição',
        progresso: 50,
        mensagem: 'Salvando grupos...',
      ));

      // Garantir que o repositório está inicializado
      try {
        await _exibicaoRepo.init();
      } catch (e) {
        debugPrint('⚠️ Repositório já inicializado ou erro: $e');
      }

      await _exibicaoRepo.salvarTodos(gruposDto);
      debugPrint('✅ DEBUG: Grupos salvos localmente');
      await _atualizarMetadadosSincronizacao('grupos_exibicao', DateTime.now());

      onProgress?.call(SyncProgress(
        etapa: 'Grupos de Exibição',
        progresso: 100,
        mensagem: 'Grupos sincronizados',
      ));

      return (total: gruposDto.length, erro: null);
    } catch (e) {
      debugPrint('Erro ao sincronizar grupos: $e');
      return (total: 0, erro: e.toString());
    }
  }

  /// Verifica se precisa sincronizar
  Future<bool> precisaSincronizar({Duration? intervaloMinimo}) async {
    final ultimaSync = await obterUltimaSincronizacao();
    if (ultimaSync == null) return true;

    final intervalo = intervaloMinimo ?? const Duration(hours: 1);
    return DateTime.now().difference(ultimaSync) > intervalo;
  }

  /// Obtém última sincronização
  Future<DateTime?> obterUltimaSincronizacao() async {
    try {
      final metadados = await _obterMetadadosSincronizacao();
      final produtos = metadados['ultima_sincronizacao_produtos'];
      if (produtos != null) {
        return DateTime.parse(produtos);
      }
      return null;
    } catch (e) {
      debugPrint('Erro ao obter última sincronização: $e');
      return null;
    }
  }

  /// Atualiza metadados de sincronização
  Future<void> _atualizarMetadadosSincronizacao(String tipo, DateTime data) async {
    try {
      final box = await Hive.openBox('sincronizacao_metadados');
      await box.put('ultima_sincronizacao_$tipo', data.toIso8601String());
      await box.put('ultima_sincronizacao_geral', data.toIso8601String());
    } catch (e) {
      debugPrint('Erro ao atualizar metadados: $e');
    }
  }

  /// Obtém metadados de sincronização
  Future<Map<String, String?>> _obterMetadadosSincronizacao() async {
    try {
      final box = await Hive.openBox('sincronizacao_metadados');
      return {
        'ultima_sincronizacao_produtos': box.get('ultima_sincronizacao_produtos') as String?,
        'ultima_sincronizacao_grupos_exibicao': box.get('ultima_sincronizacao_grupos_exibicao') as String?,
      };
    } catch (e) {
      debugPrint('Erro ao obter metadados: $e');
      return {};
    }
  }

  /// Sincroniza pedidos pendentes
  Future<({int sincronizados, int erros})> _sincronizarPedidos({
    Function(SyncProgress)? onProgress,
  }) async {
    int sincronizados = 0;
    int erros = 0;

    try {
      // Buscar pedidos pendentes
      final pedidos = await _pedidoRepo.getAll();
      final pedidosPendentes = pedidos
          .where((p) => p.syncStatus == SyncStatusPedido.pendente)
          .toList();

      if (pedidosPendentes.isEmpty) {
        onProgress?.call(SyncProgress(
          etapa: 'Pedidos',
          progresso: 100,
          mensagem: 'Nenhum pedido pendente',
        ));
        return (sincronizados: 0, erros: 0);
      }

      onProgress?.call(SyncProgress(
        etapa: 'Pedidos',
        progresso: 0,
        mensagem: 'Sincronizando ${pedidosPendentes.length} pedido(s)...',
      ));

      // Sincronizar cada pedido
      for (int i = 0; i < pedidosPendentes.length; i++) {
        final pedido = pedidosPendentes[i];
        
        try {
          // Marcar como sincronizando
          pedido.syncStatus = SyncStatusPedido.sincronizando;
          pedido.syncAttempts++;
          await _pedidoRepo.upsert(pedido);

          // Converter para DTO
          final pedidoDto = await _converterPedidoLocalParaDto(pedido);

          // Enviar para servidor
          final response = await _pedidoService.createPedido(pedidoDto);

          if (response.success && response.data != null) {
            // Sucesso: atualizar status
            pedido.syncStatus = SyncStatusPedido.sincronizado;
            pedido.remoteId = response.data!['id'] as String?;
            pedido.syncedAt = DateTime.now();
            pedido.lastSyncError = null;
            sincronizados++;
          } else {
            // Erro: marcar como erro
            pedido.syncStatus = SyncStatusPedido.erro;
            pedido.lastSyncError = response.message ?? 'Erro desconhecido';
            erros++;
          }

          await _pedidoRepo.upsert(pedido);

          // Atualizar progresso
          final progresso = ((i + 1) / pedidosPendentes.length * 100).round();
          onProgress?.call(SyncProgress(
            etapa: 'Pedidos',
            progresso: progresso,
            mensagem: 'Sincronizando pedido ${i + 1}/${pedidosPendentes.length}...',
          ));
        } catch (e) {
          debugPrint('Erro ao sincronizar pedido ${pedido.id}: $e');
          pedido.syncStatus = SyncStatusPedido.erro;
          pedido.lastSyncError = e.toString();
          pedido.syncAttempts++;
          await _pedidoRepo.upsert(pedido);
          erros++;
        }
      }

      onProgress?.call(SyncProgress(
        etapa: 'Pedidos',
        progresso: 100,
        mensagem: '$sincronizados pedido(s) sincronizado(s)',
      ));

      return (sincronizados: sincronizados, erros: erros);
    } catch (e) {
      debugPrint('Erro ao sincronizar pedidos: $e');
      return (sincronizados: sincronizados, erros: erros);
    }
  }

  /// Converte PedidoLocal para CreatePedidoDto (Map)
  Future<Map<String, dynamic>> _converterPedidoLocalParaDto(PedidoLocal pedido) async {
    debugPrint('🔄 Convertendo pedido local para DTO:');
    debugPrint('  - ID: ${pedido.id}');
    debugPrint('  - MesaId: ${pedido.mesaId}');
    debugPrint('  - ComandaId: ${pedido.comandaId}');
    debugPrint('  - Observações Gerais: ${pedido.observacoesGeral ?? "(null)"}');
    debugPrint('  - Total de itens: ${pedido.itens.length}');
    
    // Buscar configuração do restaurante para validar mesa/comanda
    String? mesaIdFinal = pedido.mesaId;
    String? comandaIdFinal = pedido.comandaId;
    
    if (_configuracaoRestauranteService != null) {
      try {
        final configResponse = await _configuracaoRestauranteService!.getConfiguracao();
        if (configResponse.success && configResponse.data != null) {
          final config = configResponse.data!;
          
          debugPrint('📋 Configuração encontrada: TipoControleVenda=${config.tipoControleVenda}');
          debugPrint('  - ControlePorMesa: ${config.controlePorMesa}');
          debugPrint('  - ControlePorComanda: ${config.controlePorComanda}');
          
          if (config.controlePorComanda) {
            // Controle por Comanda: sempre enviar comanda, mesa opcional
            debugPrint('✅ Configuração: Controle por Comanda');
            if (comandaIdFinal == null) {
              debugPrint('⚠️ AVISO: Comanda é obrigatória mas não foi informada no pedido local');
              // Não bloqueia, mas avisa - backend vai validar
            }
            // Mesa pode ser enviada se tiver (opcional)
            debugPrint('  - Enviando: ComandaId=$comandaIdFinal, MesaId=$mesaIdFinal (opcional)');
          } else if (config.controlePorMesa) {
            // Controle por Mesa: enviar apenas mesa, comanda sempre null
            debugPrint('✅ Configuração: Controle por Mesa');
            comandaIdFinal = null; // Força null quando controle é por mesa
            debugPrint('  - Enviando: MesaId=$mesaIdFinal, ComandaId=null (forçado)');
          } else {
            debugPrint('⚠️ Configuração não definida ou inválida, enviando valores originais');
          }
        } else {
          debugPrint('⚠️ Não foi possível buscar configuração, enviando valores originais');
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao buscar configuração: $e, enviando valores originais');
      }
    } else {
      debugPrint('⚠️ ConfiguracaoRestauranteService não disponível, enviando valores originais');
    }
    
    final dto = {
      'tipo': 2, // TipoPedido.Venda
      'tipoContexto': (mesaIdFinal != null || comandaIdFinal != null)
          ? 2 // TipoContextoPedido.Atendimento (para restaurante)
          : 1, // TipoContextoPedido.Direto
      'mesaId': mesaIdFinal,
      'comandaId': comandaIdFinal,
      'clienteNome': 'Consumidor Final', // TODO: Pegar do pedido se tiver
      'observacoes': pedido.observacoesGeral, // Pode ser null, está correto
      'itens': await Future.wait(pedido.itens.map((item) async {
        debugPrint('    📦 Item: ${item.produtoNome}');
        debugPrint('      - Observações: ${item.observacoes ?? "(null)"}');
        debugPrint('      - Componentes removidos: ${item.componentesRemovidos.length}');
        
        final itemMap = <String, dynamic>{
          'produtoId': item.produtoId,
          'produtoVariacaoId': item.produtoVariacaoId,
          'quantidade': item.quantidade,
          'precoUnitario': item.precoUnitario,
          'observacoes': item.observacoes, // Pode ser null, está correto
        };
        
        // Adicionar componentes removidos se houver
        if (item.componentesRemovidos.isNotEmpty) {
          // Buscar produto local para obter nomes dos componentes
          final produto = _produtoRepo.buscarPorId(item.produtoId);
          
          List<Map<String, dynamic>> componentesRemovidosDto = [];
          
          if (produto != null) {
            // Determinar qual composição usar (variação ou produto)
            List<ProdutoComposicaoLocal> composicao = [];
            
            if (item.produtoVariacaoId != null && produto.variacoes.isNotEmpty) {
              // Buscar variação específica
              final variacao = produto.variacoes.firstWhere(
                (v) => v.id == item.produtoVariacaoId,
                orElse: () => produto.variacoes.first,
              );
              
              if (variacao.composicao.isNotEmpty) {
                composicao = variacao.composicao;
                debugPrint('      📋 Usando composição da variação: ${variacao.nomeCompleto}');
              } else {
                composicao = produto.composicao;
                debugPrint('      📋 Variação sem composição, usando composição do produto');
              }
            } else {
              composicao = produto.composicao;
              debugPrint('      📋 Usando composição do produto');
            }
            
            // Mapear IDs para nomes
            for (var componenteId in item.componentesRemovidos) {
              final componente = composicao.firstWhere(
                (c) => c.componenteId == componenteId,
                orElse: () => ProdutoComposicaoLocal(
                  componenteId: componenteId,
                  componenteNome: 'Componente não encontrado',
                  isRemovivel: true,
                  ordem: 0,
                ),
              );
              
              componentesRemovidosDto.add({
                'componenteId': componenteId,
                'componenteNome': componente.componenteNome,
              });
              
              debugPrint('        ✅ Componente removido: ${componente.componenteNome} (ID: $componenteId)');
            }
          } else {
            // Produto não encontrado, enviar apenas IDs
            debugPrint('      ⚠️ Produto não encontrado localmente, enviando apenas IDs');
            componentesRemovidosDto = item.componentesRemovidos.map((componenteId) {
              return {
                'componenteId': componenteId,
                'componenteNome': '', // Backend buscará se necessário
              };
            }).toList();
          }
          
          itemMap['componentesRemovidos'] = componentesRemovidosDto;
          debugPrint('      ✅ ${componentesRemovidosDto.length} componentes removidos incluídos no DTO');
        }
        
        return itemMap;
      })),
    };
    
    debugPrint('✅ DTO gerado com ${(dto['itens'] as List).length} itens');
    return dto;
  }

  /// Sincroniza apenas pedidos (pode ser chamado manualmente)
  Future<({int sincronizados, int erros})> sincronizarPedidos({
    Function(SyncProgress)? onProgress,
  }) async {
    return _sincronizarPedidos(onProgress: onProgress);
  }

  /// Sincroniza um pedido específico
  /// Garante que o status seja sempre atualizado corretamente
  Future<bool> sincronizarPedidoIndividual(String pedidoId) async {
    // Evita sincronização duplicada
    if (_pedidosSincronizando.contains(pedidoId)) {
      debugPrint('⚠️ Pedido $pedidoId já está sendo sincronizado, ignorando...');
      return false;
    }
    
    _pedidosSincronizando.add(pedidoId);
    
    try {
      // Busca o pedido atualizado
      final pedidos = await _pedidoRepo.getAll();
      final pedido = pedidos.firstWhere(
        (p) => p.id == pedidoId,
        orElse: () => throw Exception('Pedido $pedidoId não encontrado'),
      );

      // Se já está sincronizado, não precisa fazer nada
      if (pedido.syncStatus == SyncStatusPedido.sincronizado) {
        _pedidosSincronizando.remove(pedidoId);
        debugPrint('ℹ️ Pedido $pedidoId já está sincronizado');
        return true;
      }

      // Marcar como sincronizando ANTES de qualquer operação
      pedido.syncStatus = SyncStatusPedido.sincronizando;
      pedido.syncAttempts++;
      pedido.dataAtualizacao = DateTime.now(); // Atualiza timestamp
      await _pedidoRepo.upsert(pedido);

      // Converter para DTO
      final pedidoDto = await _converterPedidoLocalParaDto(pedido);

      // Enviar para servidor
      final response = await _pedidoService.createPedido(pedidoDto);

      // Buscar pedido novamente para garantir que temos a versão mais recente
      final pedidosAtualizados = await _pedidoRepo.getAll();
      final pedidoAtualizado = pedidosAtualizados.firstWhere((p) => p.id == pedidoId);

      if (response.success && response.data != null) {
        // Sucesso: atualizar status para sincronizado
        pedidoAtualizado.syncStatus = SyncStatusPedido.sincronizado;
        pedidoAtualizado.remoteId = response.data!['id'] as String?;
        pedidoAtualizado.syncedAt = DateTime.now();
        pedidoAtualizado.lastSyncError = null;
        pedidoAtualizado.dataAtualizacao = DateTime.now();
        await _pedidoRepo.upsert(pedidoAtualizado);
        _pedidosSincronizando.remove(pedidoId);
        debugPrint('✅ Pedido $pedidoId sincronizado com sucesso');
        return true;
      } else {
        // Erro: marcar como erro
        pedidoAtualizado.syncStatus = SyncStatusPedido.erro;
        pedidoAtualizado.lastSyncError = response.message ?? 'Erro desconhecido';
        pedidoAtualizado.dataAtualizacao = DateTime.now();
        await _pedidoRepo.upsert(pedidoAtualizado);
        _pedidosSincronizando.remove(pedidoId);
        debugPrint('❌ Erro ao sincronizar pedido $pedidoId: ${response.message}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erro ao sincronizar pedido $pedidoId: $e');
      try {
        // Garante que o status seja atualizado mesmo em caso de erro
        final pedidos = await _pedidoRepo.getAll();
        final pedido = pedidos.firstWhere((p) => p.id == pedidoId);
        pedido.syncStatus = SyncStatusPedido.erro;
        pedido.lastSyncError = e.toString();
        pedido.syncAttempts++;
        pedido.dataAtualizacao = DateTime.now();
        await _pedidoRepo.upsert(pedido);
      } catch (updateError) {
        debugPrint('❌ Erro ao atualizar status do pedido $pedidoId: $updateError');
      } finally {
        // SEMPRE remove do set, mesmo em caso de erro
        _pedidosSincronizando.remove(pedidoId);
      }
      return false;
    }
  }
  
  /// Verifica se um pedido está sendo sincronizado
  bool isPedidoSincronizando(String pedidoId) {
    return _pedidosSincronizando.contains(pedidoId);
  }

  bool get isSyncing => _isSyncing;
}

