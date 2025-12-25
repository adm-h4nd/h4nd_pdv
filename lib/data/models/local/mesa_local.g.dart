// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mesa_local.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MesaLocalAdapter extends TypeAdapter<MesaLocal> {
  @override
  final int typeId = 21;

  @override
  MesaLocal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MesaLocal(
      id: fields[0] as String,
      numero: fields[1] as String,
      descricao: fields[2] as String?,
      isAtiva: fields[3] as bool,
      ultimaSincronizacao: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MesaLocal obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.numero)
      ..writeByte(2)
      ..write(obj.descricao)
      ..writeByte(3)
      ..write(obj.isAtiva)
      ..writeByte(4)
      ..write(obj.ultimaSincronizacao);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MesaLocalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
