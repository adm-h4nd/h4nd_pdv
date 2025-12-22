// Importação condicional do SDK Stone
// NOTA: Em outros flavors, este pacote NÃO estará disponível
import 'package:stone_payments/stone_payments.dart' as stone;
import '../../../../../core/payment/payment_transaction_data.dart';

/// Mapper para converter dados de transação da Stone para formato padrão
class StoneTransactionMapper {
  /// Converte uma Transaction da Stone para PaymentTransactionData padrão
  static PaymentTransactionData fromStoneTransaction(dynamic transaction) {
    // Converte data da Stone (formato: yyyy-MM-dd) para DateTime
    // Retorna DateTime com hora definida (meia-noite UTC) para garantir binding correto no backend
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      try {
        // Stone retorna data no formato yyyy-MM-dd
        // Parse e converte para UTC com hora definida (meia-noite)
        final parsedDate = DateTime.parse(dateStr);
        return DateTime.utc(parsedDate.year, parsedDate.month, parsedDate.day);
      } catch (e) {
        return null;
      }
    }
    
    // Converte amount para double (pode vir como String, int ou double)
    double? parseAmount(dynamic amountValue) {
      if (amountValue == null) return null;
      if (amountValue is double) return amountValue;
      if (amountValue is int) return amountValue.toDouble();
      if (amountValue is String) {
        try {
          // Stone retorna amount em centavos como String, converte para reais
          final centavos = int.parse(amountValue);
          return centavos / 100.0;
        } catch (e) {
          try {
            return double.parse(amountValue);
          } catch (e2) {
            return null;
          }
        }
      }
      return null;
    }
    
    return PaymentTransactionData(
      transactionStatus: transaction.transactionStatus,
      initiatorTransactionKey: transaction.initiatorTransactionKey,
      transactionReference: transaction.transactionReference,
      acquirerTransactionKey: transaction.acquirerTransactionKey,
      authorizationCode: transaction.authorizationCode,
      cardBrandName: transaction.cardBrandName,
      cardHolderName: transaction.cardHolderName,
      cardHolderNumber: transaction.cardHolderNumber,
      transactionDate: parseDate(transaction.date),
      transactionTime: transaction.time,
      typeOfTransactionEnum: transaction.typeOfTransactionEnum?.toString(),
      actionCode: transaction.actionCode,
      amount: parseAmount(transaction.amount),
      cardBrand: transaction.cardBrand?.toString(),
    );
  }
  
  /// Converte Map de metadata da Stone para PaymentTransactionData
  /// Útil quando os dados vêm em formato Map
  static PaymentTransactionData fromStoneMetadata(Map<String, dynamic> metadata) {
    // Converte amount para num (pode vir como String, int ou double)
    dynamic parseAmountForMap(dynamic amountValue) {
      if (amountValue == null) return null;
      if (amountValue is num) return amountValue;
      if (amountValue is String) {
        try {
          // Stone retorna amount em centavos como String, converte para reais
          final centavos = int.parse(amountValue);
          return centavos / 100.0;
        } catch (e) {
          try {
            return double.parse(amountValue);
          } catch (e2) {
            return null;
          }
        }
      }
      return null;
    }
    
    return PaymentTransactionData.fromMap({
      'transactionStatus': metadata['transactionStatus'],
      'initiatorTransactionKey': metadata['initiatorTransactionKey'],
      'transactionReference': metadata['transactionReference'],
      'acquirerTransactionKey': metadata['acquirerTransactionKey'],
      'authorizationCode': metadata['authorizationCode'],
      'cardBrandName': metadata['cardBrandName'],
      'cardHolderName': metadata['cardHolderName'],
      'cardHolderNumber': metadata['cardHolderNumber'],
      'transactionDate': metadata['date'],
      'transactionTime': metadata['time'],
      'typeOfTransactionEnum': metadata['typeOfTransactionEnum'],
      'actionCode': metadata['actionCode'],
      'amount': parseAmountForMap(metadata['amount']),
      'cardBrand': metadata['cardBrand'],
    });
  }
}
