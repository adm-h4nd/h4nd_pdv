// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_status_pedido.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncStatusPedidoAdapter extends TypeAdapter<SyncStatusPedido> {
  @override
  final int typeId = 12;

  @override
  SyncStatusPedido read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SyncStatusPedido.pendente;
      case 1:
        return SyncStatusPedido.sincronizando;
      case 2:
        return SyncStatusPedido.sincronizado;
      case 3:
        return SyncStatusPedido.erro;
      default:
        return SyncStatusPedido.pendente;
    }
  }

  @override
  void write(BinaryWriter writer, SyncStatusPedido obj) {
    switch (obj) {
      case SyncStatusPedido.pendente:
        writer.writeByte(0);
        break;
      case SyncStatusPedido.sincronizando:
        writer.writeByte(1);
        break;
      case SyncStatusPedido.sincronizado:
        writer.writeByte(2);
        break;
      case SyncStatusPedido.erro:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStatusPedidoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
