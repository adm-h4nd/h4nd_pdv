// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'produto_variacao_local.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProdutoVariacaoLocalAdapter extends TypeAdapter<ProdutoVariacaoLocal> {
  @override
  final int typeId = 3;

  @override
  ProdutoVariacaoLocal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProdutoVariacaoLocal(
      id: fields[0] as String,
      produtoId: fields[1] as String,
      nome: fields[2] as String?,
      nomeCompleto: fields[3] as String,
      descricao: fields[4] as String?,
      precoVenda: fields[5] as double?,
      precoEfetivo: fields[6] as double,
      sku: fields[7] as String?,
      ordem: fields[8] as int,
      valores: (fields[9] as List).cast<ProdutoVariacaoValorLocal>(),
      tipoRepresentacaoVisual: fields[10] as int?,
      icone: fields[11] as String?,
      cor: fields[12] as String?,
      imagemFileName: fields[13] as String?,
      composicao: (fields[14] as List).cast<ProdutoComposicaoLocal>(),
    );
  }

  @override
  void write(BinaryWriter writer, ProdutoVariacaoLocal obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.produtoId)
      ..writeByte(2)
      ..write(obj.nome)
      ..writeByte(3)
      ..write(obj.nomeCompleto)
      ..writeByte(4)
      ..write(obj.descricao)
      ..writeByte(5)
      ..write(obj.precoVenda)
      ..writeByte(6)
      ..write(obj.precoEfetivo)
      ..writeByte(7)
      ..write(obj.sku)
      ..writeByte(8)
      ..write(obj.ordem)
      ..writeByte(9)
      ..write(obj.valores)
      ..writeByte(10)
      ..write(obj.tipoRepresentacaoVisual)
      ..writeByte(11)
      ..write(obj.icone)
      ..writeByte(12)
      ..write(obj.cor)
      ..writeByte(13)
      ..write(obj.imagemFileName)
      ..writeByte(14)
      ..write(obj.composicao);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProdutoVariacaoLocalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProdutoVariacaoValorLocalAdapter
    extends TypeAdapter<ProdutoVariacaoValorLocal> {
  @override
  final int typeId = 4;

  @override
  ProdutoVariacaoValorLocal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProdutoVariacaoValorLocal(
      id: fields[0] as String,
      produtoVariacaoId: fields[1] as String,
      atributoValorId: fields[2] as String,
      nomeAtributo: fields[3] as String,
      nomeValor: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ProdutoVariacaoValorLocal obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.produtoVariacaoId)
      ..writeByte(2)
      ..write(obj.atributoValorId)
      ..writeByte(3)
      ..write(obj.nomeAtributo)
      ..writeByte(4)
      ..write(obj.nomeValor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProdutoVariacaoValorLocalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
