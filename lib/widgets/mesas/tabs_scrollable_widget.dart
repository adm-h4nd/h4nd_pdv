import 'package:flutter/material.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mesas/tab_data.dart';

/// Widget scrollável com setas de navegação para tabs
class TabsScrollableWidget extends StatefulWidget {
  final AdaptiveLayoutProvider adaptive;
  final List<TabData> tabs;
  final String? selectedTab;
  final Function(String?) onTabSelected;
  final Widget Function(TabData) buildTab;

  const TabsScrollableWidget({
    super.key,
    required this.adaptive,
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
    required this.buildTab,
  });

  @override
  State<TabsScrollableWidget> createState() => _TabsScrollableWidgetState();
}

class _TabsScrollableWidgetState extends State<TabsScrollableWidget> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateArrows();
      // Força atualização após o layout estar completo
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _updateArrows();
      });
    });
  }
  
  @override
  void didUpdateWidget(TabsScrollableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Atualiza setas quando as tabs mudam
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateArrows);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!_scrollController.hasClients) {
      // Se ainda não tem clients, agenda para tentar novamente
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateArrows();
      });
      return;
    }
    
    final position = _scrollController.position;
    final canScroll = position.maxScrollExtent > 0;
    final newShowLeft = canScroll && position.pixels > 0.5;
    final newShowRight = canScroll && position.pixels < position.maxScrollExtent - 0.5;
    
    if (newShowLeft != _showLeftArrow || newShowRight != _showRightArrow) {
      if (mounted) {
        setState(() {
          _showLeftArrow = newShowLeft;
          _showRightArrow = newShowRight;
        });
      }
    }
  }

  void _scrollLeft() {
    _scrollController.animateTo(
      _scrollController.offset - 200,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      _scrollController.offset + 200,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        widget.adaptive.isMobile ? 16 : 20,
        12,
        widget.adaptive.isMobile ? 16 : 20,
        8,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(widget.adaptive.isMobile ? 10 : 12),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              left: _showLeftArrow ? 40 : 0,
              right: _showRightArrow ? 40 : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: widget.tabs.map((tab) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => widget.onTabSelected(tab.comandaId),
                    child: widget.buildTab(tab),
                  ),
                );
              }).toList(),
            ),
          ),
          // Seta esquerda
          if (_showLeftArrow)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: false,
                child: Container(
                  width: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.grey.shade100,
                        Colors.grey.shade100.withOpacity(0),
                      ],
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _scrollLeft,
                      child: Center(
                        child: Icon(
                          Icons.chevron_left,
                          color: AppTheme.primaryColor,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Seta direita
          if (_showRightArrow)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: false,
                child: Container(
                  width: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Colors.grey.shade100,
                        Colors.grey.shade100.withOpacity(0),
                      ],
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _scrollRight,
                      child: Center(
                        child: Icon(
                          Icons.chevron_right,
                          color: AppTheme.primaryColor,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
