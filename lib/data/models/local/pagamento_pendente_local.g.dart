// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pagamento_pendente_local.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PagamentoPendenteLocalAdapter
    extends TypeAdapter<PagamentoPendenteLocal> {
  @override
  final int typeId = 20;

  @override
  PagamentoPendenteLocal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PagamentoPendenteLocal(
      id: fields[0] as String,
      vendaId: fields[1] as String,
      valor: fields[2] as double,
      formaPagamento: fields[3] as String,
      tipoFormaPagamento: fields[4] as int,
      numeroParcelas: fields[5] as int,
      bandeiraCartao: fields[6] as String?,
      identificadorTransacao: fields[7] as String?,
      dataPagamento: fields[8] as DateTime,
      tentativas: fields[9] as int,
      ultimoErro: fields[10] as String?,
      dataCriacao: fields[11] as DateTime,
      rotaOrigem: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PagamentoPendenteLocal obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.vendaId)
      ..writeByte(2)
      ..write(obj.valor)
      ..writeByte(3)
      ..write(obj.formaPagamento)
      ..writeByte(4)
      ..write(obj.tipoFormaPagamento)
      ..writeByte(5)
      ..write(obj.numeroParcelas)
      ..writeByte(6)
      ..write(obj.bandeiraCartao)
      ..writeByte(7)
      ..write(obj.identificadorTransacao)
      ..writeByte(8)
      ..write(obj.dataPagamento)
      ..writeByte(9)
      ..write(obj.tentativas)
      ..writeByte(10)
      ..write(obj.ultimoErro)
      ..writeByte(11)
      ..write(obj.dataCriacao)
      ..writeByte(12)
      ..write(obj.rotaOrigem);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PagamentoPendenteLocalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
