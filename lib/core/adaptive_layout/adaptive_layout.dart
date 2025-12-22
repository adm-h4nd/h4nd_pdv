import 'package:flutter/material.dart';

/// Widget que detecta o tamanho da tela e adapta o layout
class AdaptiveLayout extends StatelessWidget {
  final Widget child;
  
  const AdaptiveLayout({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        
        // Define breakpoints
        final isMobile = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 1024;
        final isDesktop = screenWidth >= 1024;
        
        return AdaptiveLayoutProvider(
          isMobile: isMobile,
          isTablet: isTablet,
          isDesktop: isDesktop,
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          child: child,
        );
      },
    );
  }
}

class AdaptiveLayoutProvider extends InheritedWidget {
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final double screenWidth;
  final double screenHeight;
  
  const AdaptiveLayoutProvider({
    super.key,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    required this.screenWidth,
    required this.screenHeight,
    required super.child,
  });
  
  static AdaptiveLayoutProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdaptiveLayoutProvider>();
  }
  
  @override
  bool updateShouldNotify(AdaptiveLayoutProvider oldWidget) {
    return isMobile != oldWidget.isMobile ||
        isTablet != oldWidget.isTablet ||
        isDesktop != oldWidget.isDesktop ||
        screenWidth != oldWidget.screenWidth ||
        screenHeight != oldWidget.screenHeight;
  }
  
  // Helper methods
  int getColumnsCount() {
    if (isMobile) return 2;
    if (isTablet) return 3;
    return 4;
  }
  
  double getCardSpacing() {
    if (isMobile) return 12.0;
    if (isTablet) return 16.0;
    return 20.0;
  }
  
  double getPadding() {
    if (isMobile) return 16.0;
    if (isTablet) return 24.0;
    return 32.0;
  }
}

