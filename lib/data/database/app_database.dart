import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/local/produto_local.dart';
import '../models/local/produto_atributo_local.dart';
import '../models/local/produto_variacao_local.dart';
import '../models/local/produto_composicao_local.dart';
import '../models/local/exibicao_produto_local.dart';
import '../models/local/item_pedido_local.dart';
import '../models/local/pedido_local.dart';
import '../models/local/sync_status_pedido.dart';
import '../models/local/pagamento_pendente_local.dart';
import '../models/local/mesa_local.dart';
import '../models/local/comanda_local.dart';
import '../models/local/configuracao_restaurante_local.dart';
import '../models/home/home_widget_type.dart';
import '../models/home/home_widget_config.dart';

/// Configuração e inicialização do Hive
class AppDatabase {
  static bool _initialized = false;

  /// Inicializa o Hive e registra os adapters
  static Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    // Registrar adapters do Hive
    // IMPORTANTE: Sempre registrar, mesmo se já estiver registrado (para hot reload)
    try {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ProdutoLocalAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ProdutoAtributoLocalAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ProdutoAtributoValorLocalAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ProdutoVariacaoLocalAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ProdutoVariacaoValorLocalAdapter());
    }
      // CRÍTICO: Adapter de composição deve estar registrado
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(ProdutoComposicaoLocalAdapter());
        debugPrint('✅ Adapter ProdutoComposicaoLocal (typeId: 5) registrado');
      } else {
        debugPrint('ℹ️ Adapter ProdutoComposicaoLocal (typeId: 5) já estava registrado');
      }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(ExibicaoProdutoLocalAdapter());
      }
      if (!Hive.isAdapterRegistered(6)) {
        Hive.registerAdapter(ItemPedidoLocalAdapter());
        debugPrint('✅ Adapter ItemPedidoLocal (typeId: 6) registrado');
      } else {
        debugPrint('ℹ️ Adapter ItemPedidoLocal (typeId: 6) já estava registrado');
      }
      if (!Hive.isAdapterRegistered(7)) {
        Hive.registerAdapter(PedidoLocalAdapter());
        debugPrint('✅ Adapter PedidoLocal (typeId: 7) registrado');
      } else {
        debugPrint('ℹ️ Adapter PedidoLocal (typeId: 7) já estava registrado');
      }
      if (!Hive.isAdapterRegistered(12)) {
        Hive.registerAdapter(SyncStatusPedidoAdapter());
        debugPrint('✅ Adapter SyncStatusPedido (typeId: 12) registrado');
      }
      if (!Hive.isAdapterRegistered(13)) {
        Hive.registerAdapter(HomeWidgetTypeAdapter());
        debugPrint('✅ Adapter HomeWidgetType (typeId: 13) registrado');
      }
      if (!Hive.isAdapterRegistered(14)) {
        Hive.registerAdapter(HomeWidgetUserConfigAdapter());
        debugPrint('✅ Adapter HomeWidgetUserConfig (typeId: 14) registrado');
      }
      if (!Hive.isAdapterRegistered(15)) {
        Hive.registerAdapter(HomeWidgetSizeAdapter());
        debugPrint('✅ Adapter HomeWidgetSize (typeId: 15) registrado');
      }
      if (!Hive.isAdapterRegistered(16)) {
        Hive.registerAdapter(HomeWidgetPositionAdapter());
        debugPrint('✅ Adapter HomeWidgetPosition (typeId: 16) registrado');
      }
      if (!Hive.isAdapterRegistered(20)) {
        Hive.registerAdapter(PagamentoPendenteLocalAdapter());
        debugPrint('✅ Adapter PagamentoPendenteLocal (typeId: 20) registrado');
      }
      if (!Hive.isAdapterRegistered(21)) {
        Hive.registerAdapter(MesaLocalAdapter());
        debugPrint('✅ Adapter MesaLocal (typeId: 21) registrado');
      }
      if (!Hive.isAdapterRegistered(22)) {
        Hive.registerAdapter(ComandaLocalAdapter());
        debugPrint('✅ Adapter ComandaLocal (typeId: 22) registrado');
      }
      // ConfiguracaoRestauranteLocalAdapter será registrado após executar build_runner
      // if (!Hive.isAdapterRegistered(23)) {
      //   Hive.registerAdapter(ConfiguracaoRestauranteLocalAdapter());
      //   debugPrint('✅ Adapter ConfiguracaoRestauranteLocal (typeId: 23) registrado');
      // }
    } catch (e) {
      // Se houver erro ao registrar (ex: já registrado), tentar registrar novamente
      debugPrint('⚠️ Erro ao registrar adapters: $e');
      // Tentar registrar o adapter de composição novamente
      try {
        Hive.registerAdapter(ProdutoComposicaoLocalAdapter());
        debugPrint('✅ Adapter ProdutoComposicaoLocal registrado com sucesso');
      } catch (e2) {
        debugPrint('❌ Erro ao registrar ProdutoComposicaoLocalAdapter: $e2');
      }
    }
    
    _initialized = true;
  }

  /// Fecha todas as boxes abertas
  static Future<void> close() async {
    await Hive.close();
    _initialized = false;
  }
}

