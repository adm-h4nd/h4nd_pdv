import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/local/mesa_local.dart';
import '../models/modules/restaurante/mesa_list_item.dart';

class MesaLocalRepository {
  static const String boxName = 'mesas';
  Box<MesaLocal>? _box;
  List<MesaLocal>? _cache;
  DateTime? _cacheTimestamp;

  Future<void> init() async {
    // Verificar se o adapter está registrado (arquivos .g.dart precisam ser gerados)
    if (!Hive.isAdapterRegistered(21)) {
      debugPrint('⚠️ MesaLocalAdapter não está registrado. Execute: flutter pub run build_runner build --delete-conflicting-outputs');
      _cache = [];
      _cacheTimestamp = DateTime.now();
      return;
    }

    if (_box == null || !_box!.isOpen) {
      try {
        _box = await Hive.openBox<MesaLocal>(boxName);
        _carregarCache();
      } catch (e) {
        debugPrint('⚠️ Erro ao abrir box mesas (schema pode estar desatualizado): $e');
        // Se houver erro, tentar deletar o box e recriar
        try {
          await Hive.deleteBoxFromDisk(boxName);
          debugPrint('✅ Box mesas deletado e será recriado');
        } catch (deleteError) {
          debugPrint('⚠️ Erro ao deletar box: $deleteError');
        }
        try {
          _box = await Hive.openBox<MesaLocal>(boxName);
          _carregarCache();
        } catch (e2) {
          debugPrint('⚠️ Erro ao recriar box mesas: $e2');
          _cache = [];
          _cacheTimestamp = DateTime.now();
        }
      }
    }
  }

  void _carregarCache() {
    if (_box == null) return;
    try {
      _cache = _box!.values
          .where((m) => m.isAtiva)
          .toList();
      _cacheTimestamp = DateTime.now();
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar cache de mesas: $e');
      _cache = [];
      _cacheTimestamp = DateTime.now();
    }
  }

  void invalidarCache() {
    _cache = null;
    _cacheTimestamp = null;
  }

  List<MesaLocal> _obterMesas() {
    if (_cache != null) {
      return _cache!;
    }
    _carregarCache();
    return _cache ?? [];
  }

  /// Salva todas as mesas (substitui existentes)
  Future<void> salvarTodas(List<MesaListItemDto> mesasDto) async {
    debugPrint('💾 MesaLocalRepository.salvarTodas chamado com ${mesasDto.length} mesas');
    
    if (_box == null || !_box!.isOpen) {
      debugPrint('🔄 Box não inicializado, chamando init()...');
      await init();
    }

    // Se o adapter não está registrado, não podemos salvar
    if (!Hive.isAdapterRegistered(21)) {
      debugPrint('❌ MesaLocalAdapter não está registrado. Não é possível salvar mesas localmente.');
      debugPrint('   Execute: flutter pub run build_runner build --delete-conflicting-outputs');
      return;
    }

    if (_box == null) {
      debugPrint('❌ Box não inicializado após init(). Não é possível salvar mesas localmente.');
      return;
    }

    debugPrint('✅ Box está inicializado e adapter está registrado');

    // Limpar box existente
    try {
      debugPrint('🧹 Limpando box existente...');
      await _box!.clear();
      debugPrint('✅ Box limpo');
    } catch (e) {
      debugPrint('⚠️ Erro ao limpar box mesas: $e');
      try {
        await _box!.close();
        await Hive.deleteBoxFromDisk(boxName);
        _box = await Hive.openBox<MesaLocal>(boxName);
        debugPrint('✅ Box mesas recriado após erro');
      } catch (recreateError) {
        debugPrint('❌ Erro ao recriar box: $recreateError');
        rethrow;
      }
    }

    // Converter DTOs para modelos locais e salvar
    debugPrint('🔄 Convertendo e salvando ${mesasDto.length} mesas...');
    int salvas = 0;
    for (final dto in mesasDto) {
      try {
        final mesaLocal = MesaLocal(
          id: dto.id,
          numero: dto.numero,
          descricao: dto.descricao,
          isAtiva: dto.ativa,
          ultimaSincronizacao: DateTime.now(),
        );
        await _box!.put(mesaLocal.id, mesaLocal);
        salvas++;
        if (salvas <= 3) {
          debugPrint('  ✅ Mesa salva: ${mesaLocal.numero} (${mesaLocal.id})');
        }
      } catch (e) {
        debugPrint('❌ Erro ao salvar mesa ${dto.numero}: $e');
      }
    }

    debugPrint('📊 Total de mesas salvas: $salvas de ${mesasDto.length}');
    
    // Invalidar cache para recarregar
    invalidarCache();
    debugPrint('✅ Cache invalidado');
  }

  /// Busca todas as mesas ativas
  List<MesaLocal> getAll() {
    return _obterMesas();
  }

  /// Busca uma mesa por ID
  MesaLocal? getById(String id) {
    if (_box == null || !_box!.isOpen) {
      return null;
    }
    return _box!.get(id);
  }

  /// Busca uma mesa por número
  MesaLocal? getByNumero(String numero) {
    final mesas = _obterMesas();
    try {
      return mesas.firstWhere((m) => m.numero.toLowerCase() == numero.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  /// Converte MesaLocal para MesaListItemDto (com status padrão "Livre")
  MesaListItemDto toListItemDto(MesaLocal mesaLocal) {
    return MesaListItemDto(
      id: mesaLocal.id,
      numero: mesaLocal.numero,
      descricao: mesaLocal.descricao,
      status: 'Livre', // Status padrão para mesas offline
      ativa: mesaLocal.isAtiva,
      permiteReserva: false, // Valor padrão
    );
  }

  /// Converte todas as mesas locais para lista de DTOs
  List<MesaListItemDto> getAllAsListItemDto() {
    return _obterMesas().map((m) => toListItemDto(m)).toList();
  }
}

