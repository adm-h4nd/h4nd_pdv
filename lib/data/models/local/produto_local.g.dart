// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'produto_local.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProdutoLocalAdapter extends TypeAdapter<ProdutoLocal> {
  @override
  final int typeId = 0;

  @override
  ProdutoLocal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProdutoLocal(
      id: fields[0] as String,
      nome: fields[1] as String,
      descricao: fields[2] as String?,
      sku: fields[3] as String?,
      referencia: fields[4] as String?,
      tipo: fields[5] as String,
      precoVenda: fields[6] as double?,
      isControlaEstoque: fields[7] as bool,
      isControlaEstoquePorVariacao: fields[8] as bool,
      unidadeBase: fields[9] as String,
      grupoId: fields[10] as String?,
      grupoNome: fields[11] as String?,
      grupoTipoRepresentacao: fields[12] as int?,
      grupoIcone: fields[13] as String?,
      grupoCor: fields[14] as String?,
      grupoImagemFileName: fields[15] as String?,
      subgrupoId: fields[16] as String?,
      subgrupoNome: fields[17] as String?,
      subgrupoTipoRepresentacao: fields[18] as int?,
      subgrupoIcone: fields[19] as String?,
      subgrupoCor: fields[20] as String?,
      subgrupoImagemFileName: fields[21] as String?,
      tipoRepresentacao: fields[22] as int,
      icone: fields[23] as String?,
      cor: fields[24] as String?,
      imagemFileName: fields[25] as String?,
      atributos: (fields[26] as List).cast<ProdutoAtributoLocal>(),
      variacoes: (fields[27] as List).cast<ProdutoVariacaoLocal>(),
      isAtivo: fields[28] as bool,
      isVendavel: fields[29] as bool,
      temVariacoes: fields[30] as bool,
      ultimaSincronizacao: fields[31] as DateTime,
      composicao: (fields[32] as List).cast<ProdutoComposicaoLocal>(),
    );
  }

  @override
  void write(BinaryWriter writer, ProdutoLocal obj) {
    writer
      ..writeByte(33)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nome)
      ..writeByte(2)
      ..write(obj.descricao)
      ..writeByte(3)
      ..write(obj.sku)
      ..writeByte(4)
      ..write(obj.referencia)
      ..writeByte(5)
      ..write(obj.tipo)
      ..writeByte(6)
      ..write(obj.precoVenda)
      ..writeByte(7)
      ..write(obj.isControlaEstoque)
      ..writeByte(8)
      ..write(obj.isControlaEstoquePorVariacao)
      ..writeByte(9)
      ..write(obj.unidadeBase)
      ..writeByte(10)
      ..write(obj.grupoId)
      ..writeByte(11)
      ..write(obj.grupoNome)
      ..writeByte(12)
      ..write(obj.grupoTipoRepresentacao)
      ..writeByte(13)
      ..write(obj.grupoIcone)
      ..writeByte(14)
      ..write(obj.grupoCor)
      ..writeByte(15)
      ..write(obj.grupoImagemFileName)
      ..writeByte(16)
      ..write(obj.subgrupoId)
      ..writeByte(17)
      ..write(obj.subgrupoNome)
      ..writeByte(18)
      ..write(obj.subgrupoTipoRepresentacao)
      ..writeByte(19)
      ..write(obj.subgrupoIcone)
      ..writeByte(20)
      ..write(obj.subgrupoCor)
      ..writeByte(21)
      ..write(obj.subgrupoImagemFileName)
      ..writeByte(22)
      ..write(obj.tipoRepresentacao)
      ..writeByte(23)
      ..write(obj.icone)
      ..writeByte(24)
      ..write(obj.cor)
      ..writeByte(25)
      ..write(obj.imagemFileName)
      ..writeByte(26)
      ..write(obj.atributos)
      ..writeByte(27)
      ..write(obj.variacoes)
      ..writeByte(28)
      ..write(obj.isAtivo)
      ..writeByte(29)
      ..write(obj.isVendavel)
      ..writeByte(30)
      ..write(obj.temVariacoes)
      ..writeByte(31)
      ..write(obj.ultimaSincronizacao)
      ..writeByte(32)
      ..write(obj.composicao);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProdutoLocalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
