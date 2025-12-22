// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_widget_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HomeWidgetPositionAdapter extends TypeAdapter<HomeWidgetPosition> {
  @override
  final int typeId = 16;

  @override
  HomeWidgetPosition read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HomeWidgetPosition(
      x: fields[0] as double,
      y: fields[1] as double,
      width: fields[2] as double,
      height: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, HomeWidgetPosition obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.x)
      ..writeByte(1)
      ..write(obj.y)
      ..writeByte(2)
      ..write(obj.width)
      ..writeByte(3)
      ..write(obj.height);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidgetPositionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HomeWidgetUserConfigAdapter extends TypeAdapter<HomeWidgetUserConfig> {
  @override
  final int typeId = 14;

  @override
  HomeWidgetUserConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HomeWidgetUserConfig(
      type: fields[0] as HomeWidgetType,
      enabled: fields[1] as bool,
      order: fields[2] as int,
      size: fields[3] as HomeWidgetSize?,
      position: fields[4] as HomeWidgetPosition?,
    );
  }

  @override
  void write(BinaryWriter writer, HomeWidgetUserConfig obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.enabled)
      ..writeByte(2)
      ..write(obj.order)
      ..writeByte(3)
      ..write(obj.size)
      ..writeByte(4)
      ..write(obj.position);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidgetUserConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HomeWidgetSizeAdapter extends TypeAdapter<HomeWidgetSize> {
  @override
  final int typeId = 15;

  @override
  HomeWidgetSize read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HomeWidgetSize.pequeno;
      case 1:
        return HomeWidgetSize.medio;
      case 2:
        return HomeWidgetSize.grande;
      default:
        return HomeWidgetSize.pequeno;
    }
  }

  @override
  void write(BinaryWriter writer, HomeWidgetSize obj) {
    switch (obj) {
      case HomeWidgetSize.pequeno:
        writer.writeByte(0);
        break;
      case HomeWidgetSize.medio:
        writer.writeByte(1);
        break;
      case HomeWidgetSize.grande:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidgetSizeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
