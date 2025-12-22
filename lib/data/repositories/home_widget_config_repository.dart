import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/home/home_widget_type.dart';
import '../models/home/home_widget_config.dart';

/// Repositório para gerenciar configurações de widgets da home
class HomeWidgetConfigRepository {
  static const String boxName = 'home_widget_config';

  Future<Box<HomeWidgetUserConfig>> _openBox() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<HomeWidgetUserConfig>(boxName);
    }
    return Hive.openBox<HomeWidgetUserConfig>(boxName);
  }

  /// Inicializa configuração padrão para um setor
  Future<void> initializeDefaultConfig(int? setor) async {
    final box = await _openBox();
    final availableWidgets = HomeWidgetAvailability.getAvailableWidgets(setor);
    
    // Verifica se já existe configuração
    if (box.isNotEmpty) {
      // Migra registros antigos que não têm o campo size ou position
      for (final key in box.keys) {
        final config = box.get(key);
        if (config != null) {
          bool needsUpdate = false;
          HomeWidgetUserConfig updatedConfig = config;
          
          if (config.size == null) {
            updatedConfig = updatedConfig.copyWith(size: HomeWidgetSize.medio);
            needsUpdate = true;
          }
          
          if (config.position == null) {
            updatedConfig = updatedConfig.copyWith(
              position: HomeWidgetPosition.defaultPosition(config.order),
            );
            needsUpdate = true;
          }
          
          if (needsUpdate) {
            await box.put(key, updatedConfig);
          }
        }
      }
      
      // Atualiza apenas widgets novos que possam ter sido adicionados
      for (final widgetType in availableWidgets) {
        if (!box.containsKey(widgetType.index)) {
          await box.put(
            widgetType.index,
            HomeWidgetUserConfig(
              type: widgetType,
              enabled: true,
              order: box.length,
              size: HomeWidgetSize.medio,
              position: HomeWidgetPosition.defaultPosition(box.length),
            ),
          );
        }
      }
      return;
    }

    // Cria configuração padrão (todos habilitados, tamanho médio, posição padrão)
    for (int i = 0; i < availableWidgets.length; i++) {
      await box.put(
        availableWidgets[i].index,
        HomeWidgetUserConfig(
          type: availableWidgets[i],
          enabled: true,
          order: i,
          size: HomeWidgetSize.medio,
          position: HomeWidgetPosition.defaultPosition(i),
        ),
      );
    }
  }

  /// Obtém todas as configurações habilitadas, ordenadas
  Future<List<HomeWidgetUserConfig>> getEnabledConfigs() async {
    final box = await _openBox();
    return box.values
        .where((config) => config.enabled)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Obtém todas as configurações (habilitadas e desabilitadas)
  Future<List<HomeWidgetUserConfig>> getAllConfigs() async {
    final box = await _openBox();
    return box.values.toList()..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Atualiza uma configuração
  Future<void> updateConfig(HomeWidgetUserConfig config) async {
    final box = await _openBox();
    await box.put(config.type.index, config);
  }

  /// Alterna estado de um widget (habilitado/desabilitado)
  Future<void> toggleWidget(HomeWidgetType type) async {
    final box = await _openBox();
    final current = box.get(type.index);
    if (current != null) {
      await box.put(
        type.index,
        current.copyWith(enabled: !current.enabled),
      );
    }
  }

  /// Reordena widgets
  Future<void> reorderWidgets(List<HomeWidgetType> newOrder) async {
    final box = await _openBox();
    for (int i = 0; i < newOrder.length; i++) {
      final current = box.get(newOrder[i].index);
      if (current != null) {
        await box.put(
          newOrder[i].index,
          current.copyWith(order: i),
        );
      }
    }
  }

  ValueListenable<Box<HomeWidgetUserConfig>> listenable() {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<HomeWidgetUserConfig>(boxName).listenable();
    }
    throw StateError('Box $boxName ainda não está aberta. Chame initializeDefaultConfig antes.');
  }
}

