// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_widget_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HomeWidgetTypeAdapter extends TypeAdapter<HomeWidgetType> {
  @override
  final int typeId = 13;

  @override
  HomeWidgetType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HomeWidgetType.sincronizarProdutos;
      case 1:
        return HomeWidgetType.sincronizarVendas;
      case 2:
        return HomeWidgetType.mesas;
      case 3:
        return HomeWidgetType.comandas;
      case 4:
        return HomeWidgetType.configuracoes;
      case 5:
        return HomeWidgetType.perfil;
      case 6:
        return HomeWidgetType.realizarPedido;
      case 7:
        return HomeWidgetType.patio;
      case 8:
        return HomeWidgetType.pedidos;
      default:
        return HomeWidgetType.sincronizarProdutos;
    }
  }

  @override
  void write(BinaryWriter writer, HomeWidgetType obj) {
    switch (obj) {
      case HomeWidgetType.sincronizarProdutos:
        writer.writeByte(0);
        break;
      case HomeWidgetType.sincronizarVendas:
        writer.writeByte(1);
        break;
      case HomeWidgetType.mesas:
        writer.writeByte(2);
        break;
      case HomeWidgetType.comandas:
        writer.writeByte(3);
        break;
      case HomeWidgetType.configuracoes:
        writer.writeByte(4);
        break;
      case HomeWidgetType.perfil:
        writer.writeByte(5);
        break;
      case HomeWidgetType.realizarPedido:
        writer.writeByte(6);
        break;
      case HomeWidgetType.patio:
        writer.writeByte(7);
        break;
      case HomeWidgetType.pedidos:
        writer.writeByte(8);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidgetTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
