import 'package:flutter/material.dart';

/// A responsive layout widget that adapts to different screen sizes
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  // Mobile breakpoint
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 650;

  // Tablet breakpoint
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 650 &&
      MediaQuery.of(context).size.width < 1100;

  // Desktop breakpoint
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    // If width is more than 1100, we consider it a desktop screen
    if (size.width >= 1100 && desktop != null) {
      return desktop!;
    }
    // If width is less than 1100 and more than 650, we consider it a tablet screen
    else if (size.width >= 650 && tablet != null) {
      return tablet!;
    }
    // Otherwise, we consider it a mobile screen
    else {
      return mobile;
    }
  }
}

/// A responsive padding widget that adapts to different screen sizes
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets mobilePadding;
  final EdgeInsets? tabletPadding;
  final EdgeInsets? desktopPadding;

  const ResponsivePadding({
    super.key,
    required this.child,
    required this.mobilePadding,
    this.tabletPadding,
    this.desktopPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _getPadding(context),
      child: child,
    );
  }

  EdgeInsets _getPadding(BuildContext context) {
    if (ResponsiveLayout.isDesktop(context) && desktopPadding != null) {
      return desktopPadding!;
    } else if (ResponsiveLayout.isTablet(context) && tabletPadding != null) {
      return tabletPadding!;
    } else {
      return mobilePadding;
    }
  }
}

/// A responsive grid view that adapts to different screen sizes
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double runSpacing;
  final EdgeInsets padding;

  const ResponsiveGridView({
    super.key,
    required this.children,
    this.mobileColumns = 2,
    this.tabletColumns = 3,
    this.desktopColumns = 4,
    this.spacing = 16,
    this.runSpacing = 16,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    int crossAxisCount;

    if (ResponsiveLayout.isDesktop(context)) {
      crossAxisCount = desktopColumns;
    } else if (ResponsiveLayout.isTablet(context)) {
      crossAxisCount = tabletColumns;
    } else {
      crossAxisCount = mobileColumns;
    }

    return Padding(
      padding: padding,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: runSpacing,
          childAspectRatio: 1,
        ),
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}

/// A responsive container that adapts its width to different screen sizes
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double mobileWidth;
  final double tabletWidth;
  final double desktopWidth;
  final double? height;
  final Alignment alignment;
  final BoxDecoration? decoration;

  const ResponsiveContainer({
    super.key,
    required this.child,
    required this.mobileWidth,
    required this.tabletWidth,
    required this.desktopWidth,
    this.height,
    this.alignment = Alignment.center,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    double width;

    if (ResponsiveLayout.isDesktop(context)) {
      width = desktopWidth;
    } else if (ResponsiveLayout.isTablet(context)) {
      width = tabletWidth;
    } else {
      width = mobileWidth;
    }

    return Container(
      width: width,
      height: height,
      alignment: alignment,
      decoration: decoration,
      child: child,
    );
  }
}

/// A responsive font size utility
class ResponsiveText extends StatelessWidget {
  final String text;
  final double mobileFontSize;
  final double? tabletFontSize;
  final double? desktopFontSize;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveText({
    super.key,
    required this.text,
    required this.mobileFontSize,
    this.tabletFontSize,
    this.desktopFontSize,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    double fontSize;

    if (ResponsiveLayout.isDesktop(context) && desktopFontSize != null) {
      fontSize = desktopFontSize!;
    } else if (ResponsiveLayout.isTablet(context) && tabletFontSize != null) {
      fontSize = tabletFontSize!;
    } else {
      fontSize = mobileFontSize;
    }

    return Text(
      text,
      style: style?.copyWith(fontSize: fontSize) ?? TextStyle(fontSize: fontSize),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}