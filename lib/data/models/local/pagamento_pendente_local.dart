import 'package:hive/hive.dart';

part 'pagamento_pendente_local.g.dart';

/// Modelo local para pagamentos pendentes de registro no backend
/// 
/// Armazena pagamentos que foram aprovados na máquina mas ainda não foram
/// registrados no servidor devido a falhas de conexão ou outros erros.
@HiveType(typeId: 20)
class PagamentoPendenteLocal extends HiveObject {
  @HiveField(0)
  final String id; // ID único do pagamento pendente
  
  @HiveField(1)
  final String vendaId; // GUID da venda
  
  @HiveField(2)
  final double valor;
  
  @HiveField(3)
  final String formaPagamento;
  
  @HiveField(4)
  final int tipoFormaPagamento; // TipoFormaPagamento enum
  
  @HiveField(5)
  final int numeroParcelas;
  
  @HiveField(6)
  final String? bandeiraCartao;
  
  @HiveField(7)
  final String? identificadorTransacao;
  
  @HiveField(8)
  final DateTime dataPagamento;
  
  @HiveField(9)
  final int tentativas; // Contador de tentativas de registro
  
  @HiveField(10)
  final String? ultimoErro; // Mensagem do último erro
  
  @HiveField(11)
  final DateTime dataCriacao;
  
  @HiveField(12)
  final String? rotaOrigem; // Rota para navegar após sucesso (ex: '/mesas/detalhes')
  
  PagamentoPendenteLocal({
    required this.id,
    required this.vendaId,
    required this.valor,
    required this.formaPagamento,
    required this.tipoFormaPagamento,
    this.numeroParcelas = 1,
    this.bandeiraCartao,
    this.identificadorTransacao,
    required this.dataPagamento,
    this.tentativas = 0,
    this.ultimoErro,
    required this.dataCriacao,
    this.rotaOrigem,
  });
  
  /// Cria uma cópia com tentativas incrementadas
  PagamentoPendenteLocal copyWith({
    String? id,
    String? vendaId,
    double? valor,
    String? formaPagamento,
    int? tipoFormaPagamento,
    int? numeroParcelas,
    String? bandeiraCartao,
    String? identificadorTransacao,
    DateTime? dataPagamento,
    int? tentativas,
    String? ultimoErro,
    DateTime? dataCriacao,
    String? rotaOrigem,
  }) {
    return PagamentoPendenteLocal(
      id: id ?? this.id,
      vendaId: vendaId ?? this.vendaId,
      valor: valor ?? this.valor,
      formaPagamento: formaPagamento ?? this.formaPagamento,
      tipoFormaPagamento: tipoFormaPagamento ?? this.tipoFormaPagamento,
      numeroParcelas: numeroParcelas ?? this.numeroParcelas,
      bandeiraCartao: bandeiraCartao ?? this.bandeiraCartao,
      identificadorTransacao: identificadorTransacao ?? this.identificadorTransacao,
      dataPagamento: dataPagamento ?? this.dataPagamento,
      tentativas: tentativas ?? this.tentativas,
      ultimoErro: ultimoErro ?? this.ultimoErro,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      rotaOrigem: rotaOrigem ?? this.rotaOrigem,
    );
  }
  
  /// Verifica se já atingiu o limite de tentativas (3)
  bool get atingiuLimiteTentativas => tentativas >= 3;
}
