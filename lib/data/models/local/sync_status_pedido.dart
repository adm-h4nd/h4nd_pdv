import 'package:hive/hive.dart';

part 'sync_status_pedido.g.dart';

@HiveType(typeId: 12)
enum SyncStatusPedido {
  @HiveField(0)
  pendente,
  @HiveField(1)
  sincronizando,
  @HiveField(2)
  sincronizado,
  @HiveField(3)
  erro,
}
