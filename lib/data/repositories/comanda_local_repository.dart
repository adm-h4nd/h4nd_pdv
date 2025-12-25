import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/local/comanda_local.dart';
import '../models/modules/restaurante/comanda_list_item.dart';

class ComandaLocalRepository {
  static const String boxName = 'comandas';
  Box<ComandaLocal>? _box;
  List<ComandaLocal>? _cache;
  DateTime? _cacheTimestamp;

  Future<void> init() async {
    // Verificar se o adapter está registrado (arquivos .g.dart precisam ser gerados)
    if (!Hive.isAdapterRegistered(22)) {
      debugPrint('⚠️ ComandaLocalAdapter não está registrado. Execute: flutter pub run build_runner build --delete-conflicting-outputs');
      _cache = [];
      _cacheTimestamp = DateTime.now();
      return;
    }

    if (_box == null || !_box!.isOpen) {
      try {
        _box = await Hive.openBox<ComandaLocal>(boxName);
        _carregarCache();
      } catch (e) {
        debugPrint('⚠️ Erro ao abrir box comandas (schema pode estar desatualizado): $e');
        // Se houver erro, tentar deletar o box e recriar
        try {
          await Hive.deleteBoxFromDisk(boxName);
          debugPrint('✅ Box comandas deletado e será recriado');
        } catch (deleteError) {
          debugPrint('⚠️ Erro ao deletar box: $deleteError');
        }
        try {
          _box = await Hive.openBox<ComandaLocal>(boxName);
          _carregarCache();
        } catch (e2) {
          debugPrint('⚠️ Erro ao recriar box comandas: $e2');
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
          .where((c) => c.isAtiva)
          .toList();
      _cacheTimestamp = DateTime.now();
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar cache de comandas: $e');
      _cache = [];
      _cacheTimestamp = DateTime.now();
    }
  }

  void invalidarCache() {
    _cache = null;
    _cacheTimestamp = null;
  }

  List<ComandaLocal> _obterComandas() {
    if (_cache != null) {
      return _cache!;
    }
    _carregarCache();
    return _cache ?? [];
  }

  /// Salva todas as comandas (substitui existentes)
  Future<void> salvarTodas(List<ComandaListItemDto> comandasDto) async {
    debugPrint('💾 ComandaLocalRepository.salvarTodas chamado com ${comandasDto.length} comandas');
    
    if (_box == null || !_box!.isOpen) {
      debugPrint('🔄 Box não inicializado, chamando init()...');
      await init();
    }

    // Se o adapter não está registrado, não podemos salvar
    if (!Hive.isAdapterRegistered(22)) {
      debugPrint('❌ ComandaLocalAdapter não está registrado. Não é possível salvar comandas localmente.');
      debugPrint('   Execute: flutter pub run build_runner build --delete-conflicting-outputs');
      return;
    }

    if (_box == null) {
      debugPrint('❌ Box não inicializado após init(). Não é possível salvar comandas localmente.');
      return;
    }

    debugPrint('✅ Box está inicializado e adapter está registrado');

    // Limpar box existente
    try {
      debugPrint('🧹 Limpando box existente...');
      await _box!.clear();
      debugPrint('✅ Box limpo');
    } catch (e) {
      debugPrint('⚠️ Erro ao limpar box comandas: $e');
      try {
        await _box!.close();
        await Hive.deleteBoxFromDisk(boxName);
        _box = await Hive.openBox<ComandaLocal>(boxName);
        debugPrint('✅ Box comandas recriado após erro');
      } catch (recreateError) {
        debugPrint('❌ Erro ao recriar box: $recreateError');
        rethrow;
      }
    }

    // Converter DTOs para modelos locais e salvar
    debugPrint('🔄 Convertendo e salvando ${comandasDto.length} comandas...');
    int salvas = 0;
    for (final dto in comandasDto) {
      try {
        final comandaLocal = ComandaLocal(
          id: dto.id,
          numero: dto.numero,
          codigoBarras: dto.codigoBarras,
          descricao: dto.descricao,
          isAtiva: dto.ativa,
          ultimaSincronizacao: DateTime.now(),
        );
        await _box!.put(comandaLocal.id, comandaLocal);
        salvas++;
        if (salvas <= 3) {
          debugPrint('  ✅ Comanda salva: ${comandaLocal.numero} (${comandaLocal.id})');
        }
      } catch (e) {
        debugPrint('❌ Erro ao salvar comanda ${dto.numero}: $e');
      }
    }

    debugPrint('📊 Total de comandas salvas: $salvas de ${comandasDto.length}');
    
    // Invalidar cache para recarregar
    invalidarCache();
    debugPrint('✅ Cache invalidado');
  }

  /// Busca todas as comandas ativas
  List<ComandaLocal> getAll() {
    return _obterComandas();
  }

  /// Busca uma comanda por ID
  ComandaLocal? getById(String id) {
    if (_box == null || !_box!.isOpen) {
      return null;
    }
    return _box!.get(id);
  }

  /// Busca uma comanda por número
  ComandaLocal? getByNumero(String numero) {
    final comandas = _obterComandas();
    try {
      return comandas.firstWhere((c) => c.numero.toLowerCase() == numero.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  /// Busca uma comanda por código de barras
  ComandaLocal? getByCodigoBarras(String codigoBarras) {
    final comandas = _obterComandas();
    try {
      return comandas.firstWhere(
        (c) => c.codigoBarras != null && 
              c.codigoBarras!.toLowerCase() == codigoBarras.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Converte ComandaLocal para ComandaListItemDto (com status padrão "Livre")
  ComandaListItemDto toListItemDto(ComandaLocal comandaLocal) {
    return ComandaListItemDto(
      id: comandaLocal.id,
      numero: comandaLocal.numero,
      codigoBarras: comandaLocal.codigoBarras,
      descricao: comandaLocal.descricao,
      status: 'Livre', // Status padrão para comandas offline
      ativa: comandaLocal.isAtiva,
      totalPedidosAtivos: 0,
      valorTotalPedidosAtivos: 0.0,
    );
  }

  /// Converte todas as comandas locais para lista de DTOs
  List<ComandaListItemDto> getAllAsListItemDto() {
    return _obterComandas().map((c) => toListItemDto(c)).toList();
  }
}

