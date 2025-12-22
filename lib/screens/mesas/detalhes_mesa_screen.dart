import 'package:flutter/material.dart';
import '../../data/models/modules/restaurante/mesa_list_item.dart';
import '../../models/mesas/entidade_produtos.dart';
import 'detalhes_produtos_mesa_screen.dart';

/// Tela de detalhes da mesa com lista de produtos agrupados
class DetalhesMesaScreen extends StatelessWidget {
  final MesaListItemDto mesa;

  const DetalhesMesaScreen({
    super.key,
    required this.mesa,
  });

  @override
  Widget build(BuildContext context) {
    return DetalhesProdutosMesaScreen(
      entidade: MesaComandaInfo(
        id: mesa.id,
        numero: mesa.numero,
        descricao: mesa.descricao,
        status: mesa.status,
        tipo: TipoEntidade.mesa,
      ),
    );
  }
}
