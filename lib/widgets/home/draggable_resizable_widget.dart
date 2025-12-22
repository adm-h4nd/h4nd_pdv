import 'package:flutter/material.dart';
import '../../data/models/home/home_widget_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import 'home_widget_tile.dart';
import 'grid_layout_manager.dart' show GridLayoutManager, GridPosition;

/// Widget que pode ser arrastado e redimensionado em grid
class DraggableResizableWidget extends StatefulWidget {
  final HomeWidgetUserConfig config;
  final int? badgeCount;
  final VoidCallback onTap;
  final Function(HomeWidgetPosition) onPositionChanged;
  final bool isEditing;
  final Size parentSize; // Tamanho dinâmico do canvas (para posicionamento visual)
  final Size baseSize; // Tamanho base fixo (para conversões de grid)
  final GridLayoutManager gridManager;

  const DraggableResizableWidget({
    super.key,
    required this.config,
    this.badgeCount,
    required this.onTap,
    required this.onPositionChanged,
    required this.isEditing,
    required this.parentSize,
    required this.baseSize,
    required this.gridManager,
  });

  @override
  State<DraggableResizableWidget> createState() => _DraggableResizableWidgetState();
}

class _DraggableResizableWidgetState extends State<DraggableResizableWidget> {
  late HomeWidgetPosition _position;
  bool _isDragging = false;
  bool _isResizing = false;
  Offset? _dragStartOffset;
  HomeWidgetPosition? _resizeStartPosition;
  String? _resizeEdge; // 'left', 'right', 'top', 'bottom', 'topLeft', 'topRight', 'bottomLeft', 'bottomRight'
  String? _hoverEdge; // Para mudar o cursor quando hover
  Offset _accumulatedDelta = Offset.zero; // Acumula o delta total durante o resize

  @override
  void initState() {
    super.initState();
    _position = widget.config.positionOrDefault;
  }

  @override
  void didUpdateWidget(DraggableResizableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.position != widget.config.position) {
      _position = widget.config.positionOrDefault;
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.isEditing) return;
    
    final localPosition = details.localPosition;
    // Usa tamanho base para cálculos de detecção de resize
    final widgetWidth = _position.width * widget.baseSize.width;
    final widgetHeight = _position.height * widget.baseSize.height;

    final adaptive = AdaptiveLayoutProvider.of(context);
    final isMobile = adaptive?.isMobile ?? false;
    
    if (isMobile) {
      // No mobile: LÓGICA SIMPLIFICADA
      // Resize APENAS nos indicadores visíveis (quadrados grandes nos cantos)
      // Arrastar em QUALQUER outro lugar
      const indicatorTouchSize = 60.0; // Área grande de toque nos indicadores
      const indicatorVisualSize = 32.0; // Tamanho visual do indicador
      const indicatorOffset = -16.0; // Offset do indicador
      
      // Verifica se está tocando nos indicadores (área expandida para facilitar)
      final isTouchingTopLeft = localPosition.dx < indicatorTouchSize && 
                                localPosition.dy < indicatorTouchSize;
      final isTouchingTopRight = localPosition.dx > widgetWidth - indicatorTouchSize && 
                                 localPosition.dy < indicatorTouchSize;
      final isTouchingBottomLeft = localPosition.dx < indicatorTouchSize && 
                                   localPosition.dy > widgetHeight - indicatorTouchSize;
      final isTouchingBottomRight = localPosition.dx > widgetWidth - indicatorTouchSize && 
                                    localPosition.dy > widgetHeight - indicatorTouchSize;
      
      final isTouchingIndicator = isTouchingTopLeft || isTouchingTopRight || 
                                  isTouchingBottomLeft || isTouchingBottomRight;
      
      if (isTouchingIndicator) {
        // Inicia resize nos indicadores
        _isResizing = true;
        _isDragging = false;
        _resizeStartPosition = _position;
        _dragStartOffset = localPosition;
        _accumulatedDelta = Offset.zero;
        
        // Determina qual canto
        if (isTouchingTopLeft) {
          _resizeEdge = 'topLeft';
        } else if (isTouchingTopRight) {
          _resizeEdge = 'topRight';
        } else if (isTouchingBottomLeft) {
          _resizeEdge = 'bottomLeft';
        } else {
          _resizeEdge = 'bottomRight';
        }
      } else {
        // Qualquer outro lugar: arrastar
        _isDragging = true;
        _isResizing = false;
        _dragStartOffset = details.localPosition;
      }
    } else {
      // Desktop: lógica original com mouse
      const resizeHandleSize = 20.0;
      final isNearLeft = localPosition.dx < resizeHandleSize;
      final isNearRight = localPosition.dx > widgetWidth - resizeHandleSize;
      final isNearTop = localPosition.dy < resizeHandleSize;
      final isNearBottom = localPosition.dy > widgetHeight - resizeHandleSize;
      
      if (isNearLeft || isNearRight || isNearTop || isNearBottom) {
        // Inicia resize
        _isResizing = true;
        _isDragging = false;
        _resizeStartPosition = _position;
        _dragStartOffset = localPosition;
        _accumulatedDelta = Offset.zero;
        
        // Determina qual borda/canto
        final isInCorner = (isNearTop && isNearLeft) ||
                           (isNearTop && isNearRight) ||
                           (isNearBottom && isNearLeft) ||
                           (isNearBottom && isNearRight);
        
        if (isInCorner) {
          if (isNearTop && isNearLeft) {
            _resizeEdge = 'topLeft';
          } else if (isNearTop && isNearRight) {
            _resizeEdge = 'topRight';
          } else if (isNearBottom && isNearLeft) {
            _resizeEdge = 'bottomLeft';
          } else {
            _resizeEdge = 'bottomRight';
          }
        } else {
          final distToLeft = localPosition.dx;
          final distToRight = widgetWidth - localPosition.dx;
          final distToTop = localPosition.dy;
          final distToBottom = widgetHeight - localPosition.dy;
          
          final minDist = [distToLeft, distToRight, distToTop, distToBottom].reduce((a, b) => a < b ? a : b);
          
          if (minDist == distToLeft) {
            _resizeEdge = 'left';
          } else if (minDist == distToRight) {
            _resizeEdge = 'right';
          } else if (minDist == distToTop) {
            _resizeEdge = 'top';
          } else {
            _resizeEdge = 'bottom';
          }
        }
      } else {
        // Inicia drag
        _isDragging = true;
        _isResizing = false;
        _dragStartOffset = details.localPosition;
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.isEditing) return;

      if (_isDragging && _dragStartOffset != null) {
        final delta = details.delta;
        // Usa tamanho base para cálculos de movimento
        final newX = (_position.x * widget.baseSize.width + delta.dx) / widget.baseSize.width;
        final newY = (_position.y * widget.baseSize.height + delta.dy) / widget.baseSize.height;

      // Permite movimento livre durante o drag (sem snap imediato)
      final newPosition = HomeWidgetPosition(
        x: newX.clamp(0.0, 1.0 - _position.width),
        y: newY.clamp(0.0, 1.0 - _position.height),
        width: _position.width,
        height: _position.height,
      );

      setState(() {
        _position = newPosition;
      });
    } else if (_isResizing && _resizeStartPosition != null && _resizeEdge != null) {
      // Acumula o delta incremental
        _accumulatedDelta += details.delta;

        // Usa tamanho base para cálculos de resize
        final totalDeltaX = _accumulatedDelta.dx / widget.baseSize.width;
        final totalDeltaY = _accumulatedDelta.dy / widget.baseSize.height;

      double newWidth = _resizeStartPosition!.width;
      double newHeight = _resizeStartPosition!.height;
      double newX = _resizeStartPosition!.x;
      double newY = _resizeStartPosition!.y;

      // Processa resize baseado na borda/canto usando delta acumulado
      switch (_resizeEdge) {
        case 'right':
          newWidth = (_resizeStartPosition!.width + totalDeltaX).clamp(0.05, 1.0 - _resizeStartPosition!.x);
          break;
        case 'left':
          newWidth = (_resizeStartPosition!.width - totalDeltaX).clamp(0.05, 1.0);
          newX = (_resizeStartPosition!.x + totalDeltaX).clamp(0.0, 1.0 - newWidth);
          break;
        case 'bottom':
          newHeight = (_resizeStartPosition!.height + totalDeltaY).clamp(0.05, 1.0 - _resizeStartPosition!.y);
          break;
        case 'top':
          newHeight = (_resizeStartPosition!.height - totalDeltaY).clamp(0.05, 1.0);
          newY = (_resizeStartPosition!.y + totalDeltaY).clamp(0.0, 1.0 - newHeight);
          break;
        case 'topLeft':
          newWidth = (_resizeStartPosition!.width - totalDeltaX).clamp(0.05, 1.0);
          newHeight = (_resizeStartPosition!.height - totalDeltaY).clamp(0.05, 1.0);
          newX = (_resizeStartPosition!.x + totalDeltaX).clamp(0.0, 1.0 - newWidth);
          newY = (_resizeStartPosition!.y + totalDeltaY).clamp(0.0, 1.0 - newHeight);
          break;
        case 'topRight':
          newWidth = (_resizeStartPosition!.width + totalDeltaX).clamp(0.05, 1.0 - _resizeStartPosition!.x);
          newHeight = (_resizeStartPosition!.height - totalDeltaY).clamp(0.05, 1.0);
          newY = (_resizeStartPosition!.y + totalDeltaY).clamp(0.0, 1.0 - newHeight);
          break;
        case 'bottomLeft':
          newWidth = (_resizeStartPosition!.width - totalDeltaX).clamp(0.05, 1.0);
          newHeight = (_resizeStartPosition!.height + totalDeltaY).clamp(0.05, 1.0 - _resizeStartPosition!.y);
          newX = (_resizeStartPosition!.x + totalDeltaX).clamp(0.0, 1.0 - newWidth);
          break;
        case 'bottomRight':
          newWidth = (_resizeStartPosition!.width + totalDeltaX).clamp(0.05, 1.0 - _resizeStartPosition!.x);
          newHeight = (_resizeStartPosition!.height + totalDeltaY).clamp(0.05, 1.0 - _resizeStartPosition!.y);
          break;
      }

      // Permite movimento livre durante o resize (sem snap imediato)
      final newPosition = HomeWidgetPosition(
        x: newX,
        y: newY,
        width: newWidth,
        height: newHeight,
      );

      setState(() {
        _position = newPosition;
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isDragging || _isResizing) {
      // Snap para grid (sem empurrar outros widgets)
      // Usa baseSize para conversões de grid (estável) mas converte para parentSize (dinâmico)
      final currentGrid = widget.gridManager.percentageToGrid(_position, widget.baseSize);
      
      // Garante tamanho mínimo de 1 célula e limites do grid
      final snappedGrid = GridPosition(
        x: currentGrid.x.clamp(0, widget.gridManager.columns - currentGrid.width.clamp(1, widget.gridManager.columns)),
        y: currentGrid.y.clamp(0, widget.gridManager.rows - currentGrid.height.clamp(1, widget.gridManager.rows)),
        width: currentGrid.width.clamp(1, widget.gridManager.columns - currentGrid.x),
        height: currentGrid.height.clamp(1, widget.gridManager.rows - currentGrid.y),
      );
      
      // Converte de grid para porcentagem usando baseSize (estável)
      final snappedPositionBase = widget.gridManager.gridToPercentage(snappedGrid, widget.baseSize);
      // Mas ajusta para o tamanho atual do canvas
      final snappedPosition = HomeWidgetPosition(
        x: snappedPositionBase.x,
        y: snappedPositionBase.y,
        width: snappedPositionBase.width,
        height: snappedPositionBase.height,
      );
      
      setState(() {
        _position = snappedPosition;
      });
      
      widget.onPositionChanged(snappedPosition);
    }
    _isDragging = false;
    _isResizing = false;
    _dragStartOffset = null;
    _resizeStartPosition = null;
    _resizeEdge = null;
    _accumulatedDelta = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    const margin = 4.0; // Margem entre widgets
    // Usa sempre o tamanho base fixo para calcular dimensões visuais
    // Isso garante que os widgets não mudem de tamanho quando o canvas muda
    final left = _position.x * widget.baseSize.width + margin;
    final top = _position.y * widget.baseSize.height + margin;
    final width = _position.width * widget.baseSize.width - (margin * 2);
    final height = _position.height * widget.baseSize.height - (margin * 2);

    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        // MouseRegion só funciona no desktop, no mobile usa GestureDetector
        onHover: widget.isEditing ? (event) {
          final adaptive = AdaptiveLayoutProvider.of(context);
          if (adaptive?.isMobile ?? false) return; // Não processa hover no mobile
          
          final localPosition = event.localPosition;
          final widgetWidth = width;
          final widgetHeight = height;
          const resizeHandleSize = 20.0; // Desktop usa tamanho menor
          
          final isNearLeft = localPosition.dx < resizeHandleSize;
          final isNearRight = localPosition.dx > widgetWidth - resizeHandleSize;
          final isNearTop = localPosition.dy < resizeHandleSize;
          final isNearBottom = localPosition.dy > widgetHeight - resizeHandleSize;
          
          String? newHoverEdge;
          if (isNearTop && isNearLeft) {
            newHoverEdge = 'topLeft';
          } else if (isNearTop && isNearRight) {
            newHoverEdge = 'topRight';
          } else if (isNearBottom && isNearLeft) {
            newHoverEdge = 'bottomLeft';
          } else if (isNearBottom && isNearRight) {
            newHoverEdge = 'bottomRight';
          } else if (isNearLeft) {
            newHoverEdge = 'left';
          } else if (isNearRight) {
            newHoverEdge = 'right';
          } else if (isNearTop) {
            newHoverEdge = 'top';
          } else if (isNearBottom) {
            newHoverEdge = 'bottom';
          }
          
          if (_hoverEdge != newHoverEdge) {
            setState(() {
              _hoverEdge = newHoverEdge;
            });
          }
        } : null,
        onExit: widget.isEditing ? (_) {
          if (_hoverEdge != null) {
            setState(() {
              _hoverEdge = null;
            });
          }
        } : null,
        cursor: _getCursorForEdge(_hoverEdge),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque, // Captura todos os toques
          onPanStart: widget.isEditing ? _onPanStart : null,
          onPanUpdate: widget.isEditing ? _onPanUpdate : null,
          onPanEnd: widget.isEditing ? _onPanEnd : null,
          onTap: widget.isEditing ? null : widget.onTap,
          child: Stack(
          children: [
            // Widget principal
            SizedBox(
              width: width,
              height: height,
              child: IgnorePointer(
                // Ignora toques apenas quando está editando (para permitir drag/resize)
                ignoring: widget.isEditing,
                child: HomeWidgetTile(
                  type: widget.config.type,
                  onTap: widget.onTap,
                  badgeCount: widget.badgeCount,
                  size: widget.config.sizeOrDefault,
                ),
              ),
            ),
            // Indicadores visuais de resize quando está editando
            if (widget.isEditing)
              ..._buildResizeIndicators(width, height),
            // Borda de seleção quando está editando
            if (widget.isEditing)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  MouseCursor _getCursorForEdge(String? edge) {
    if (!widget.isEditing || edge == null) {
      return MouseCursor.defer;
    }
    
    switch (edge) {
      case 'left':
      case 'right':
        return SystemMouseCursors.resizeLeftRight;
      case 'top':
      case 'bottom':
        return SystemMouseCursors.resizeUpDown;
      case 'topLeft':
      case 'bottomRight':
        return SystemMouseCursors.resizeUpLeftDownRight;
      case 'topRight':
      case 'bottomLeft':
        return SystemMouseCursors.resizeUpRightDownLeft;
      default:
        return MouseCursor.defer;
    }
  }

  List<Widget> _buildResizeIndicators(double width, double height) {
    // No mobile, faz os indicadores muito maiores e mais visíveis para facilitar o toque
    final adaptive = AdaptiveLayoutProvider.of(context);
    final isMobile = adaptive?.isMobile ?? false;
    final indicatorSize = isMobile ? 32.0 : 6.0; // Muito maior no mobile (32px)
    final indicatorOffset = isMobile ? -16.0 : -3.0; // Offset maior para ficar mais visível
    
    return [
      // Cantos - quadrados muito maiores no mobile com área de toque expandida
      Positioned(
        top: indicatorOffset,
        left: indicatorOffset,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            _isResizing = true;
            _isDragging = false;
            _resizeStartPosition = _position;
            _resizeEdge = 'topLeft';
            _accumulatedDelta = Offset.zero;
          },
          child: Container(
            // Área de toque maior no mobile (48x48px mesmo que o indicador seja 32px)
            width: isMobile ? 48.0 : indicatorSize,
            height: isMobile ? 48.0 : indicatorSize,
            alignment: Alignment.center,
            child: Container(
              width: indicatorSize,
              height: indicatorSize,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                border: isMobile ? Border.all(color: Colors.white, width: 3) : null,
              ),
            ),
          ),
        ),
      ),
      Positioned(
        top: indicatorOffset,
        right: indicatorOffset,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            _isResizing = true;
            _isDragging = false;
            _resizeStartPosition = _position;
            _resizeEdge = 'topRight';
            _accumulatedDelta = Offset.zero;
          },
          child: Container(
            width: isMobile ? 48.0 : indicatorSize,
            height: isMobile ? 48.0 : indicatorSize,
            alignment: Alignment.center,
            child: Container(
              width: indicatorSize,
              height: indicatorSize,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                border: isMobile ? Border.all(color: Colors.white, width: 3) : null,
              ),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: indicatorOffset,
        left: indicatorOffset,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            _isResizing = true;
            _isDragging = false;
            _resizeStartPosition = _position;
            _resizeEdge = 'bottomLeft';
            _accumulatedDelta = Offset.zero;
          },
          child: Container(
            width: isMobile ? 48.0 : indicatorSize,
            height: isMobile ? 48.0 : indicatorSize,
            alignment: Alignment.center,
            child: Container(
              width: indicatorSize,
              height: indicatorSize,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                border: isMobile ? Border.all(color: Colors.white, width: 3) : null,
              ),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: indicatorOffset,
        right: indicatorOffset,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            _isResizing = true;
            _isDragging = false;
            _resizeStartPosition = _position;
            _resizeEdge = 'bottomRight';
            _accumulatedDelta = Offset.zero;
          },
          child: Container(
            width: isMobile ? 48.0 : indicatorSize,
            height: isMobile ? 48.0 : indicatorSize,
            alignment: Alignment.center,
            child: Container(
              width: indicatorSize,
              height: indicatorSize,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                border: isMobile ? Border.all(color: Colors.white, width: 3) : null,
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

