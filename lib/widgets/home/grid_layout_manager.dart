import 'package:flutter/material.dart';
import '../../data/models/home/home_widget_config.dart';

/// Gerenciador de layout em grid que evita sobreposição
class GridLayoutManager {
  final int columns;
  final int rows;
  final double cellWidth;
  final double cellHeight;

  GridLayoutManager({
    required this.columns,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
  });

  /// Converte posição em porcentagem para coordenadas de grid
  GridPosition percentageToGrid(HomeWidgetPosition position, Size containerSize) {
    final x = (position.x * containerSize.width / cellWidth).round();
    final y = (position.y * containerSize.height / cellHeight).round();
    final width = (position.width * containerSize.width / cellWidth).round().clamp(1, columns);
    final height = (position.height * containerSize.height / cellHeight).round().clamp(1, rows);
    
    return GridPosition(
      x: x.clamp(0, columns - width),
      y: y.clamp(0, rows - height),
      width: width,
      height: height,
    );
  }

  /// Converte coordenadas de grid para posição em porcentagem
  HomeWidgetPosition gridToPercentage(GridPosition grid, Size containerSize) {
    return HomeWidgetPosition(
      x: (grid.x * cellWidth) / containerSize.width,
      y: (grid.y * cellHeight) / containerSize.height,
      width: (grid.width * cellWidth) / containerSize.width,
      height: (grid.height * cellHeight) / containerSize.height,
    );
  }

  /// Verifica se duas posições de grid se sobrepõem
  bool overlaps(GridPosition a, GridPosition b) {
    return !(a.x + a.width <= b.x ||
        b.x + b.width <= a.x ||
        a.y + a.height <= b.y ||
        b.y + b.height <= a.y);
  }

  /// Encontra a posição mais próxima disponível para um widget
  GridPosition findNearestAvailablePosition(
    GridPosition target,
    List<GridPosition> occupied,
    int maxX,
    int maxY,
  ) {
    // Tenta a posição exata primeiro
    if (!_isOccupied(target, occupied, maxX, maxY)) {
      return target;
    }

    // Busca em espiral ao redor da posição alvo
    for (int radius = 1; radius < (maxX + maxY); radius++) {
      for (int dx = -radius; dx <= radius; dx++) {
        for (int dy = -radius; dy <= radius; dy++) {
          if (dx.abs() == radius || dy.abs() == radius) {
            final newX = (target.x + dx).clamp(0, maxX - target.width);
            final newY = (target.y + dy).clamp(0, maxY - target.height);
            
            final candidate = GridPosition(
              x: newX,
              y: newY,
              width: target.width,
              height: target.height,
            );

            if (!_isOccupied(candidate, occupied, maxX, maxY)) {
              return candidate;
            }
          }
        }
      }
    }

    // Se não encontrou, retorna a posição original
    return target;
  }

  /// Verifica se uma posição está ocupada
  bool _isOccupied(GridPosition position, List<GridPosition> occupied, int maxX, int maxY) {
    if (position.x < 0 || position.y < 0 ||
        position.x + position.width > maxX ||
        position.y + position.height > maxY) {
      return true;
    }

    for (final occupiedPos in occupied) {
      if (overlaps(position, occupiedPos)) {
        return true;
      }
    }
    return false;
  }

  /// Empurra widgets recursivamente quando há colisão (estilo Grafana)
  void _pushWidgetsRecursively(
    List<GridPosition> gridPositions,
    int pushingIndex,
    Set<int> processed,
    {int depth = 0}
  ) {
    // Previne loops infinitos
    if (depth > 50 || processed.contains(pushingIndex)) return;
    processed.add(pushingIndex);

    final pushingWidget = gridPositions[pushingIndex];
    final overlappingWidgets = <int>[];

    // Encontra todos os widgets que estão sobrepostos com o widget sendo empurrado
    for (int i = 0; i < gridPositions.length; i++) {
      if (i == pushingIndex) continue;
      if (overlaps(pushingWidget, gridPositions[i])) {
        overlappingWidgets.add(i);
      }
    }

    // Ordena widgets sobrepostos por proximidade (mais próximo primeiro)
    overlappingWidgets.sort((a, b) {
      final distA = (gridPositions[a].y - pushingWidget.y).abs() + 
                    (gridPositions[a].x - pushingWidget.x).abs();
      final distB = (gridPositions[b].y - pushingWidget.y).abs() + 
                    (gridPositions[b].x - pushingWidget.x).abs();
      return distA.compareTo(distB);
    });

    // Empurra cada widget sobreposto
    for (final overlappedIndex in overlappingWidgets) {
      final overlappedWidget = gridPositions[overlappedIndex];
      
      // Calcula a direção do empurrão baseado na posição relativa
      final centerYOverlapped = overlappedWidget.y + overlappedWidget.height / 2;
      final centerYPushing = pushingWidget.y + pushingWidget.height / 2;
      final centerXOverlapped = overlappedWidget.x + overlappedWidget.width / 2;
      final centerXPushing = pushingWidget.x + pushingWidget.width / 2;
      
      final pushDown = centerYOverlapped >= centerYPushing;
      final pushRight = centerXOverlapped >= centerXPushing;

      GridPosition? newPosition;

      // Tenta empurrar na direção mais natural primeiro
      if (pushDown) {
        // Empurra para baixo
        final newY = pushingWidget.y + pushingWidget.height;
        if (newY + overlappedWidget.height <= rows) {
          final candidate = GridPosition(
            x: overlappedWidget.x,
            y: newY,
            width: overlappedWidget.width,
            height: overlappedWidget.height,
          );
          
          // Verifica se a posição está livre
          bool isFree = true;
          for (int j = 0; j < gridPositions.length; j++) {
            if (j == overlappedIndex || j == pushingIndex) continue;
            if (overlaps(candidate, gridPositions[j])) {
              isFree = false;
              break;
            }
          }
          
          if (isFree) {
            newPosition = candidate;
          }
        }
      }

      if (newPosition == null && pushRight) {
        // Empurra para direita
        final newX = pushingWidget.x + pushingWidget.width;
        if (newX + overlappedWidget.width <= columns) {
          final candidate = GridPosition(
            x: newX,
            y: overlappedWidget.y,
            width: overlappedWidget.width,
            height: overlappedWidget.height,
          );
          
          bool isFree = true;
          for (int j = 0; j < gridPositions.length; j++) {
            if (j == overlappedIndex || j == pushingIndex) continue;
            if (overlaps(candidate, gridPositions[j])) {
              isFree = false;
              break;
            }
          }
          
          if (isFree) {
            newPosition = candidate;
          }
        }
      }

      // Se ainda não encontrou posição, busca a primeira posição livre abaixo
      if (newPosition == null) {
        for (int newY = overlappedWidget.y + 1; newY + overlappedWidget.height <= rows; newY++) {
          final candidate = GridPosition(
            x: overlappedWidget.x,
            y: newY,
            width: overlappedWidget.width,
            height: overlappedWidget.height,
          );
          
          bool isFree = true;
          for (int j = 0; j < gridPositions.length; j++) {
            if (j == overlappedIndex || j == pushingIndex) continue;
            if (overlaps(candidate, gridPositions[j])) {
              isFree = false;
              break;
            }
          }
          
          if (isFree) {
            newPosition = candidate;
            break;
          }
        }
      }

      if (newPosition != null) {
        gridPositions[overlappedIndex] = newPosition;
        // Recursivamente empurra widgets que podem ter sido afetados
        _pushWidgetsRecursively(
          gridPositions, 
          overlappedIndex, 
          processed,
          depth: depth + 1,
        );
      }
    }
  }

  /// Reorganiza widgets empurrando-os quando há colisão (estilo Grafana)
  List<HomeWidgetPosition> reorganizeWidgets(
    List<HomeWidgetPosition> positions,
    int changedIndex,
    Size containerSize,
  ) {
    final gridPositions = positions.map((p) => percentageToGrid(p, containerSize)).toList();
    final changedGrid = gridPositions[changedIndex];
    
    // Snap para grid
    final snappedGrid = GridPosition(
      x: changedGrid.x.clamp(0, columns - changedGrid.width),
      y: changedGrid.y.clamp(0, rows - changedGrid.height),
      width: changedGrid.width.clamp(1, columns),
      height: changedGrid.height.clamp(1, rows),
    );
    
    gridPositions[changedIndex] = snappedGrid;

    // Empurra widgets recursivamente
    final processed = <int>{};
    _pushWidgetsRecursively(gridPositions, changedIndex, processed);

    // Converte de volta para porcentagem
    return gridPositions.map((g) => gridToPercentage(g, containerSize)).toList();
  }
}

/// Posição em coordenadas de grid
class GridPosition {
  final int x;
  final int y;
  final int width;
  final int height;

  GridPosition({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  GridPosition copyWith({
    int? x,
    int? y,
    int? width,
    int? height,
  }) {
    return GridPosition(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

