/// Utilitários para formatação de datas e horas
class DateFormatter {
  /// Formata data e hora para exibição
  /// Retorna formato como "Hoje às 14:30" ou "01/12/2024 às 14:30"
  static String formatarDataHora(DateTime data) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dataDate = DateTime(data.year, data.month, data.day);
    
    String dataStr;
    if (dataDate == today) {
      dataStr = 'Hoje';
    } else if (dataDate == today.subtract(const Duration(days: 1))) {
      dataStr = 'Ontem';
    } else {
      dataStr = '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    }
    
    final horaStr = '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
    
    return '$dataStr às $horaStr';
  }
}
