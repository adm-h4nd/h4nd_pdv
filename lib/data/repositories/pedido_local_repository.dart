import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/local/pedido_local.dart';
import '../models/local/sync_status_pedido.dart';

class PedidoLocalRepository {
  static const String boxName = 'pedidos_local';

  Future<Box<PedidoLocal>> _openBox() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<PedidoLocal>(boxName);
    }
    return Hive.openBox<PedidoLocal>(boxName);
  }

  Future<List<PedidoLocal>> getAll() async {
    final box = await _openBox();
    return box.values.toList();
  }

  ValueListenable<Box<PedidoLocal>> listenable() {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<PedidoLocal>(boxName).listenable();
    }
    // Se não estiver aberta ainda, abra de forma preguiçosa e exponha o listenable depois
    // (o caller pode usar FutureBuilder antes de usar este listenable)
    throw StateError('Box $boxName ainda não está aberta. Chame getAll/open antes.');
  }

  Future<void> upsert(PedidoLocal pedido) async {
    final box = await _openBox();
    await box.put(pedido.id, pedido);
  }

  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }

  Future<void> clear() async {
    final box = await _openBox();
    await box.clear();
  }

  /// Conta quantos pedidos estão pendentes de sincronização
  int countPendentes() {
    if (!Hive.isBoxOpen(boxName)) {
      return 0;
    }
    final box = Hive.box<PedidoLocal>(boxName);
    return box.values
        .where((p) => p.syncStatus != SyncStatusPedido.sincronizado)
        .length;
  }

  /// Retorna um Stream que emite eventos quando a box é modificada
  /// Útil para escutar mudanças em tempo real
  Future<Stream<BoxEvent>> watch() async {
    final box = await _openBox();
    return box.watch();
  }
}

