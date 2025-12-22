// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'produto_atributo_local.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProdutoAtributoLocalAdapter extends TypeAdapter<ProdutoAtributoLocal> {
  @override
  final int typeId = 1;

  @override
  ProdutoAtributoLocal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProdutoAtributoLocal(
      id: fields[0] as String,
      produtoId: fields[1] as String,
      atributoId: fields[2] as String,
      nome: fields[3] as String,
      descricao: fields[4] as String?,
      permiteSelecaoProporcional: fields[5] as bool,
      ordem: fields[6] as int,
      valores: (fields[7] as List).cast<ProdutoAtributoValorLocal>(),
    );
  }

  @override
  void write(BinaryWriter writer, ProdutoAtributoLocal obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.produtoId)
      ..writeByte(2)
      ..write(obj.atributoId)
      ..writeByte(3)
      ..write(obj.nome)
      ..writeByte(4)
      ..write(obj.descricao)
      ..writeByte(5)
      ..write(obj.permiteSelecaoProporcional)
      ..writeByte(6)
      ..write(obj.ordem)
      ..writeByte(7)
      ..write(obj.valores);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProdutoAtributoLocalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProdutoAtributoValorLocalAdapter
    extends TypeAdapter<ProdutoAtributoValorLocal> {
  @override
  final int typeId = 2;

  @override
  ProdutoAtributoValorLocal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProdutoAtributoValorLocal(
      id: fields[0] as String,
      atributoValorId: fields[1] as String,
      nome: fields[2] as String,
      descricao: fields[3] as String?,
      ordem: fields[4] as int,
      isActive: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ProdutoAtributoValorLocal obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.atributoValorId)
      ..writeByte(2)
      ..write(obj.nome)
      ..writeByte(3)
      ..write(obj.descricao)
      ..writeByte(4)
      ..write(obj.ordem)
      ..writeByte(5)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProdutoAtributoValorLocalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
