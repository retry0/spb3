import 'package:flutter/material.dart';

class CustomBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<CustomBottomNavigationItem> items;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final double elevation;
  final double borderRadius;
  final EdgeInsetsGeometry margin;
  final double height;
  final Duration animationDuration;

  const CustomBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.elevation = 8,
    this.borderRadius = 20,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.height = 64,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? 
        (Theme.of(context).brightness == Brightness.light 
            ? Colors.white 
            : Theme.of(context).colorScheme.surface);
    
    final selectedColor = selectedItemColor ?? Theme.of(context).colorScheme.primary;
    final unselectedColor = unselectedItemColor ?? 
        Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    return Container(
      margin: margin,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = index == currentIndex;
          
          return Expanded(
            child: InkWell(
              onTap: () => onTap(index),
              splashColor: selectedColor.withOpacity(0.1),
              highlightColor: selectedColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(borderRadius),
              child: AnimatedContainer(
                duration: animationDuration,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? selectedColor.withOpacity(0.1) 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected ? selectedColor : unselectedColor,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? selectedColor : unselectedColor,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class CustomBottomNavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const CustomBottomNavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}