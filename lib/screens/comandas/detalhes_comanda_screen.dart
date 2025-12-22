import 'package:flutter/material.dart';
import '../../data/models/modules/restaurante/comanda_list_item.dart';
import '../../models/mesas/entidade_produtos.dart';
import '../mesas/detalhes_produtos_mesa_screen.dart';

/// Tela de detalhes da comanda com lista de produtos agrupados
class DetalhesComandaScreen extends StatelessWidget {
  final ComandaListItemDto comanda;

  const DetalhesComandaScreen({
    super.key,
    required this.comanda,
  });

  @override
  Widget build(BuildContext context) {
    return DetalhesProdutosMesaScreen(
      entidade: MesaComandaInfo(
        id: comanda.id,
        numero: comanda.numero,
        descricao: comanda.descricao,
        status: comanda.status,
        tipo: TipoEntidade.comanda,
        codigoBarras: comanda.codigoBarras,
      ),
    );
  }
}
