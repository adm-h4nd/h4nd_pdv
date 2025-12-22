// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exibicao_produto_local.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExibicaoProdutoLocalAdapter extends TypeAdapter<ExibicaoProdutoLocal> {
  @override
  final int typeId = 10;

  @override
  ExibicaoProdutoLocal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExibicaoProdutoLocal(
      id: fields[0] as String,
      nome: fields[1] as String,
      descricao: fields[2] as String?,
      categoriaPaiId: fields[3] as String?,
      ordem: fields[4] as int,
      tipoRepresentacao: fields[5] as int,
      icone: fields[6] as String?,
      cor: fields[7] as String?,
      imagemFileName: fields[8] as String?,
      isAtiva: fields[9] as bool,
      produtoIds: (fields[10] as List).cast<String>(),
      categoriasFilhas: (fields[11] as List).cast<ExibicaoProdutoLocal>(),
      ultimaSincronizacao: fields[12] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ExibicaoProdutoLocal obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nome)
      ..writeByte(2)
      ..write(obj.descricao)
      ..writeByte(3)
      ..write(obj.categoriaPaiId)
      ..writeByte(4)
      ..write(obj.ordem)
      ..writeByte(5)
      ..write(obj.tipoRepresentacao)
      ..writeByte(6)
      ..write(obj.icone)
      ..writeByte(7)
      ..write(obj.cor)
      ..writeByte(8)
      ..write(obj.imagemFileName)
      ..writeByte(9)
      ..write(obj.isAtiva)
      ..writeByte(10)
      ..write(obj.produtoIds)
      ..writeByte(11)
      ..write(obj.categoriasFilhas)
      ..writeByte(12)
      ..write(obj.ultimaSincronizacao);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExibicaoProdutoLocalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
