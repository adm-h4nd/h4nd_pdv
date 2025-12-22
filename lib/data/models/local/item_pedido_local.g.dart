// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item_pedido_local.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemPedidoLocalAdapter extends TypeAdapter<ItemPedidoLocal> {
  @override
  final int typeId = 6;

  @override
  ItemPedidoLocal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ItemPedidoLocal(
      id: fields[0] as String,
      produtoId: fields[1] as String,
      produtoNome: fields[2] as String,
      produtoVariacaoId: fields[3] as String?,
      produtoVariacaoNome: fields[4] as String?,
      precoUnitario: fields[5] as double,
      quantidade: fields[6] as int,
      observacoes: fields[7] as String?,
      proporcoesAtributos: (fields[8] as Map?)?.cast<String, double>(),
      componentesRemovidos: (fields[9] as List).cast<String>(),
      valoresAtributosSelecionados: (fields[12] as Map?)?.map(
          (dynamic k, dynamic v) =>
              MapEntry(k as String, (v as List).cast<String>())),
      syncStatus: fields[11] as String?,
      dataAdicao: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ItemPedidoLocal obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.produtoId)
      ..writeByte(2)
      ..write(obj.produtoNome)
      ..writeByte(3)
      ..write(obj.produtoVariacaoId)
      ..writeByte(4)
      ..write(obj.produtoVariacaoNome)
      ..writeByte(5)
      ..write(obj.precoUnitario)
      ..writeByte(6)
      ..write(obj.quantidade)
      ..writeByte(7)
      ..write(obj.observacoes)
      ..writeByte(8)
      ..write(obj.proporcoesAtributos)
      ..writeByte(9)
      ..write(obj.componentesRemovidos)
      ..writeByte(12)
      ..write(obj.valoresAtributosSelecionados)
      ..writeByte(11)
      ..write(obj.syncStatus)
      ..writeByte(10)
      ..write(obj.dataAdicao);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemPedidoLocalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
