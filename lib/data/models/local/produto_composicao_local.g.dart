// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'produto_composicao_local.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProdutoComposicaoLocalAdapter
    extends TypeAdapter<ProdutoComposicaoLocal> {
  @override
  final int typeId = 5;

  @override
  ProdutoComposicaoLocal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProdutoComposicaoLocal(
      componenteId: fields[0] as String,
      componenteNome: fields[1] as String,
      isRemovivel: fields[2] as bool,
      ordem: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ProdutoComposicaoLocal obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.componenteId)
      ..writeByte(1)
      ..write(obj.componenteNome)
      ..writeByte(2)
      ..write(obj.isRemovivel)
      ..writeByte(3)
      ..write(obj.ordem);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProdutoComposicaoLocalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
