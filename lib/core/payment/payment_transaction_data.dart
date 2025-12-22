/// Modelo padrão de dados de transação de pagamento
/// 
/// Todos os providers de pagamento devem retornar seus dados neste formato padrão.
/// Cada provider é responsável por mapear seus dados específicos para este modelo.
class PaymentTransactionData {
  /// Status da transação (ex: APPROVED, AUTHORIZED, etc.)
  final String? transactionStatus;
  
  /// Chave única da transação gerada pelo iniciador
  final String? initiatorTransactionKey;
  
  /// Referência da transação (UUID)
  final String? transactionReference;
  
  /// Chave da transação do adquirente
  final String? acquirerTransactionKey;
  
  /// Código de autorização da transação
  final String? authorizationCode;
  
  /// Nome da bandeira do cartão (ex: MASTERCARD, VISA)
  final String? cardBrandName;
  
  /// Nome do portador do cartão
  final String? cardHolderName;
  
  /// Número do cartão mascarado (ex: 530033****2561)
  final String? cardHolderNumber;
  
  /// Data da transação (formato: yyyy-MM-dd)
  final DateTime? transactionDate;
  
  /// Hora da transação (formato: HH:mm:ss)
  final String? transactionTime;
  
  /// Tipo de transação (CREDIT, DEBIT, PIX)
  final String? typeOfTransactionEnum;
  
  /// Código de ação da transação
  final String? actionCode;
  
  /// Valor da transação
  final double? amount;
  
  /// Bandeira do cartão (código curto, ex: MC, VI)
  final String? cardBrand;
  
  PaymentTransactionData({
    this.transactionStatus,
    this.initiatorTransactionKey,
    this.transactionReference,
    this.acquirerTransactionKey,
    this.authorizationCode,
    this.cardBrandName,
    this.cardHolderName,
    this.cardHolderNumber,
    this.transactionDate,
    this.transactionTime,
    this.typeOfTransactionEnum,
    this.actionCode,
    this.amount,
    this.cardBrand,
  });
  
  /// Cria um PaymentTransactionData a partir de um Map genérico
  /// Útil para providers que retornam dados em formato Map
  factory PaymentTransactionData.fromMap(Map<String, dynamic>? map) {
    if (map == null) return PaymentTransactionData();
    
    // Tenta converter transactionDate de String para DateTime
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      try {
        // Tenta formatos comuns: yyyy-MM-dd, dd/MM/yyyy, etc.
        if (dateStr.contains('-')) {
          return DateTime.parse(dateStr.split(' ').first);
        }
        return null;
      } catch (e) {
        return null;
      }
    }
    
    return PaymentTransactionData(
      transactionStatus: map['transactionStatus'] as String?,
      initiatorTransactionKey: map['initiatorTransactionKey'] as String?,
      transactionReference: map['transactionReference'] as String?,
      acquirerTransactionKey: map['acquirerTransactionKey'] as String?,
      authorizationCode: map['authorizationCode'] as String?,
      cardBrandName: map['cardBrandName'] as String?,
      cardHolderName: map['cardHolderName'] as String?,
      cardHolderNumber: map['cardHolderNumber'] as String?,
      transactionDate: map['transactionDate'] is DateTime 
          ? map['transactionDate'] as DateTime?
          : parseDate(map['transactionDate'] as String?),
      transactionTime: map['transactionTime'] as String?,
      typeOfTransactionEnum: map['typeOfTransactionEnum']?.toString(),
      actionCode: map['actionCode'] as String?,
      amount: map['amount'] != null ? (map['amount'] as num).toDouble() : null,
      cardBrand: map['cardBrand'] as String?,
    );
  }
  
  /// Converte para Map para envio ao backend
  Map<String, dynamic> toMap() {
    // Converte transactionDate para formato ISO 8601 completo para garantir binding correto no backend
    String? formatTransactionDate(DateTime? date) {
      if (date == null) return null;
      // Se não tem hora, adiciona meia-noite UTC
      final dateWithTime = date.hour == 0 && date.minute == 0 && date.second == 0
          ? DateTime.utc(date.year, date.month, date.day)
          : date.toUtc();
      return dateWithTime.toIso8601String();
    }
    
    // Verifica se string não está vazia antes de incluir
    bool isNotEmpty(String? value) => value != null && value.trim().isNotEmpty;
    
    return {
      if (isNotEmpty(transactionStatus)) 'transactionStatus': transactionStatus,
      if (isNotEmpty(initiatorTransactionKey)) 'initiatorTransactionKey': initiatorTransactionKey,
      if (isNotEmpty(transactionReference)) 'transactionReference': transactionReference,
      if (isNotEmpty(acquirerTransactionKey)) 'acquirerTransactionKey': acquirerTransactionKey,
      if (isNotEmpty(authorizationCode)) 'authorizationCode': authorizationCode,
      if (isNotEmpty(cardBrandName)) 'cardBrandName': cardBrandName,
      if (isNotEmpty(cardHolderName)) 'cardHolderName': cardHolderName,
      if (isNotEmpty(cardHolderNumber)) 'cardHolderNumber': cardHolderNumber,
      if (transactionDate != null) 'transactionDate': formatTransactionDate(transactionDate),
      if (isNotEmpty(transactionTime)) 'transactionTime': transactionTime,
      if (isNotEmpty(typeOfTransactionEnum)) 'typeOfTransactionEnum': typeOfTransactionEnum,
      if (isNotEmpty(actionCode)) 'actionCode': actionCode,
    };
  }
  
  /// Verifica se há dados de transação válidos
  bool get hasTransactionData => 
      transactionStatus != null ||
      initiatorTransactionKey != null ||
      transactionReference != null ||
      acquirerTransactionKey != null ||
      authorizationCode != null;
}
