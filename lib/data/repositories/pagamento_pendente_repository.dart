import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/local/pagamento_pendente_local.dart';

class PagamentoPendenteRepository {
  static const String boxName = 'pagamentos_pendentes';

  Future<Box<PagamentoPendenteLocal>> _openBox() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<PagamentoPendenteLocal>(boxName);
    }
    return Hive.openBox<PagamentoPendenteLocal>(boxName);
  }

  /// Busca todos os pagamentos pendentes
  Future<List<PagamentoPendenteLocal>> getAll() async {
    final box = await _openBox();
    return box.values.toList();
  }

  /// Busca um pagamento pendente por ID
  Future<PagamentoPendenteLocal?> getById(String id) async {
    final box = await _openBox();
    return box.get(id);
  }

  /// Salva ou atualiza um pagamento pendente
  Future<void> upsert(PagamentoPendenteLocal pagamento) async {
    final box = await _openBox();
    await box.put(pagamento.id, pagamento);
    debugPrint('💾 Pagamento pendente salvo: ${pagamento.id} (tentativas: ${pagamento.tentativas})');
  }

  /// Remove um pagamento pendente
  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);
    debugPrint('🗑️ Pagamento pendente removido: $id');
  }

  /// Remove todos os pagamentos pendentes
  Future<void> clear() async {
    final box = await _openBox();
    await box.clear();
  }

  /// Conta quantos pagamentos estão pendentes
  int countPendentes() {
    if (!Hive.isBoxOpen(boxName)) {
      return 0;
    }
    final box = Hive.box<PagamentoPendenteLocal>(boxName);
    return box.length;
  }

  /// Busca pagamentos pendentes de uma venda específica
  Future<List<PagamentoPendenteLocal>> getByVendaId(String vendaId) async {
    final box = await _openBox();
    return box.values.where((p) => p.vendaId == vendaId).toList();
  }
}
