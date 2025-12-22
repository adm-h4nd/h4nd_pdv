import 'package:flutter/material.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';

/// Layout staggered/masonry para widgets de tamanhos diferentes
class StaggeredGridLayout extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const StaggeredGridLayout({
    super.key,
    required this.children,
    this.spacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) {
      return const SizedBox.shrink();
    }

    if (adaptive.isMobile) {
      // Mobile: coluna simples
      return Column(
        children: children
            .map((child) => Padding(
                  padding: EdgeInsets.only(bottom: spacing),
                  child: child,
                ))
            .toList(),
      );
    }

    // Desktop/Tablet: layout staggered
    return _buildStaggeredLayout(adaptive);
  }

  Widget _buildStaggeredLayout(AdaptiveLayoutProvider adaptive) {
    // Calcula número de colunas baseado na largura da tela
    final columns = _getColumnCount(adaptive.screenWidth);

    // Cria lista de colunas
    final List<List<Widget>> columnsList = List.generate(columns, (_) => []);

    // Distribui widgets nas colunas de forma balanceada (round-robin simples)
    for (int i = 0; i < children.length; i++) {
      columnsList[i % columns].add(children[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columnsList.map((columnChildren) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: Column(
              children: columnChildren
                  .map((child) => Padding(
                        padding: EdgeInsets.only(bottom: spacing),
                        child: child,
                      ))
                  .toList(),
            ),
          ),
        );
      }).toList(),
    );
  }

  int _getColumnCount(double screenWidth) {
    if (screenWidth < 1024) return 2; // Tablet
    if (screenWidth < 1440) return 3; // Desktop pequeno
    if (screenWidth < 1920) return 4; // Desktop médio
    return 5; // Desktop grande
  }
}

