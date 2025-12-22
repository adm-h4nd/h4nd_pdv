// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedido_local.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PedidoLocalAdapter extends TypeAdapter<PedidoLocal> {
  @override
  final int typeId = 7;

  @override
  PedidoLocal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PedidoLocal(
      id: fields[0] as String,
      mesaId: fields[1] as String?,
      comandaId: fields[2] as String?,
      itens: (fields[3] as List?)?.cast<ItemPedidoLocal>(),
      observacoesGeral: fields[4] as String?,
      dataCriacao: fields[5] as DateTime?,
      dataAtualizacao: fields[6] as DateTime?,
      syncStatus: fields[7] as SyncStatusPedido,
      syncAttempts: fields[8] as int,
      lastSyncError: fields[9] as String?,
      syncedAt: fields[10] as DateTime?,
      remoteId: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PedidoLocal obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.mesaId)
      ..writeByte(2)
      ..write(obj.comandaId)
      ..writeByte(3)
      ..write(obj.itens)
      ..writeByte(4)
      ..write(obj.observacoesGeral)
      ..writeByte(5)
      ..write(obj.dataCriacao)
      ..writeByte(6)
      ..write(obj.dataAtualizacao)
      ..writeByte(7)
      ..write(obj.syncStatus)
      ..writeByte(8)
      ..write(obj.syncAttempts)
      ..writeByte(9)
      ..write(obj.lastSyncError)
      ..writeByte(10)
      ..write(obj.syncedAt)
      ..writeByte(11)
      ..write(obj.remoteId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PedidoLocalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
