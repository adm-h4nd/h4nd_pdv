import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/local/configuracao_restaurante_local.dart';
import '../models/modules/restaurante/configuracao_restaurante_dto.dart';

class ConfiguracaoRestauranteLocalRepository {
  static const String boxName = 'configuracao_restaurante';
  static const String keyConfiguracao = 'configuracao';
  Box<ConfiguracaoRestauranteLocal>? _box;

  Future<void> init() async {
    // Verificar se o adapter está registrado (arquivos .g.dart precisam ser gerados)
    if (!Hive.isAdapterRegistered(23)) {
      debugPrint('⚠️ ConfiguracaoRestauranteLocalAdapter não está registrado. Execute: flutter pub run build_runner build --delete-conflicting-outputs');
      return;
    }

    if (_box == null || !_box!.isOpen) {
      try {
        _box = await Hive.openBox<ConfiguracaoRestauranteLocal>(boxName);
        debugPrint('✅ Box configuracao_restaurante aberto');
      } catch (e) {
        debugPrint('⚠️ Erro ao abrir box configuracao_restaurante (schema pode estar desatualizado): $e');
        // Se houver erro, tentar deletar o box e recriar
        try {
          await Hive.deleteBoxFromDisk(boxName);
          debugPrint('✅ Box configuracao_restaurante deletado e será recriado');
        } catch (deleteError) {
          debugPrint('⚠️ Erro ao deletar box: $deleteError');
        }
        try {
          _box = await Hive.openBox<ConfiguracaoRestauranteLocal>(boxName);
          debugPrint('✅ Box configuracao_restaurante recriado');
        } catch (e2) {
          debugPrint('❌ Erro ao recriar box configuracao_restaurante: $e2');
        }
      }
    }
  }

  /// Salva a configuração localmente
  Future<void> salvar(ConfiguracaoRestauranteDto dto) async {
    if (_box == null || !_box!.isOpen) {
      debugPrint('⚠️ Box configuracao_restaurante não está aberto');
      return;
    }

    try {
      final local = ConfiguracaoRestauranteLocal.fromDto(dto);
      await _box!.put(keyConfiguracao, local);
      debugPrint('✅ Configuração do restaurante salva localmente');
    } catch (e) {
      debugPrint('❌ Erro ao salvar configuração localmente: $e');
    }
  }

  /// Carrega a configuração localmente
  ConfiguracaoRestauranteDto? carregar() {
    if (_box == null || !_box!.isOpen) {
      debugPrint('⚠️ Box configuracao_restaurante não está aberto');
      return null;
    }

    try {
      final local = _box!.get(keyConfiguracao);
      if (local == null) {
        debugPrint('ℹ️ Nenhuma configuração encontrada localmente');
        return null;
      }

      // Converte de Map para DTO
      final json = local.toJson();
      final dto = ConfiguracaoRestauranteDto.fromJson(json);
      debugPrint('✅ Configuração do restaurante carregada localmente');
      return dto;
    } catch (e) {
      debugPrint('❌ Erro ao carregar configuração localmente: $e');
      return null;
    }
  }

  /// Limpa a configuração local (útil quando muda de empresa ou faz logout)
  Future<void> limpar() async {
    if (_box == null || !_box!.isOpen) {
      return;
    }

    try {
      await _box!.delete(keyConfiguracao);
      debugPrint('✅ Configuração do restaurante removida localmente');
    } catch (e) {
      debugPrint('❌ Erro ao limpar configuração localmente: $e');
    }
  }

  /// Verifica se há configuração salva localmente
  bool temConfiguracaoSalva() {
    if (_box == null || !_box!.isOpen) {
      return false;
    }

    return _box!.containsKey(keyConfiguracao);
  }
}

