// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comanda_local.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ComandaLocalAdapter extends TypeAdapter<ComandaLocal> {
  @override
  final int typeId = 22;

  @override
  ComandaLocal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ComandaLocal(
      id: fields[0] as String,
      numero: fields[1] as String,
      codigoBarras: fields[2] as String?,
      descricao: fields[3] as String?,
      isAtiva: fields[4] as bool,
      ultimaSincronizacao: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ComandaLocal obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.numero)
      ..writeByte(2)
      ..write(obj.codigoBarras)
      ..writeByte(3)
      ..write(obj.descricao)
      ..writeByte(4)
      ..write(obj.isAtiva)
      ..writeByte(5)
      ..write(obj.ultimaSincronizacao);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComandaLocalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
