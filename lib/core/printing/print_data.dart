/// Dados estruturados para impressão (sem formatação específica)
class PrintData {
  final PrintHeader header;
  final PrintEntityInfo entityInfo;
  final List<PrintItem> items;
  final PrintTotals totals;
  final PrintFooter footer;
  
  PrintData({
    required this.header,
    required this.entityInfo,
    required this.items,
    required this.totals,
    required this.footer,
  });
}

class PrintHeader {
  final String title;
  final String? subtitle;
  final DateTime dateTime;
  
  PrintHeader({
    required this.title,
    this.subtitle,
    required this.dateTime,
  });
}

class PrintEntityInfo {
  final String? mesaNome;
  final String? comandaCodigo;
  final String clienteNome;
  
  PrintEntityInfo({
    this.mesaNome,
    this.comandaCodigo,
    required this.clienteNome,
  });
}

class PrintItem {
  final String produtoNome;
  final String? produtoVariacaoNome;
  final double quantidade;
  final double precoUnitario;
  final double valorTotal;
  final List<String> componentesRemovidos;
  
  PrintItem({
    required this.produtoNome,
    this.produtoVariacaoNome,
    required this.quantidade,
    required this.precoUnitario,
    required this.valorTotal,
    this.componentesRemovidos = const [],
  });
}

class PrintTotals {
  final double subtotal;
  final double descontoTotal;
  final double acrescimoTotal;
  final double impostosTotal;
  final double valorTotal;
  
  PrintTotals({
    required this.subtotal,
    required this.descontoTotal,
    this.acrescimoTotal = 0.0,
    this.impostosTotal = 0.0,
    required this.valorTotal,
  });
}

class PrintFooter {
  final String? message;
  
  PrintFooter({this.message});
}

