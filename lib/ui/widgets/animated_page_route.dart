import 'package:flutter/material.dart';

/// A custom page route that provides smooth transitions between pages
class AnimatedPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final RouteSettings? settings;
  final bool fadeIn;
  final bool slideFromRight;
  final bool slideFromBottom;
  final bool scale;
  final Duration duration;
  final Duration reverseDuration;
  final Color? barrierColor;
  final bool barrierDismissible;
  final String? barrierLabel;
  final bool maintainState;

  AnimatedPageRoute({
    required this.page,
    this.settings,
    this.fadeIn = true,
    this.slideFromRight = true,
    this.slideFromBottom = false,
    this.scale = false,
    this.duration = const Duration(milliseconds: 300),
    this.reverseDuration = const Duration(milliseconds: 300),
    this.barrierColor,
    this.barrierDismissible = false,
    this.barrierLabel,
    this.maintainState = true,
  }) : super(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
              reverseCurve: Curves.easeOut,
            );

            final List<Widget> transitions = [];

            // Base child widget
            Widget transitionChild = child;

            // Apply scale transition if requested
            if (scale) {
              transitionChild = ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
                child: transitionChild,
              );
            }

            // Apply slide transition if requested
            if (slideFromRight) {
              transitionChild = SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: transitionChild,
              );
            } else if (slideFromBottom) {
              transitionChild = SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: transitionChild,
              );
            }

            // Apply fade transition if requested
            if (fadeIn) {
              transitionChild = FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
                child: transitionChild,
              );
            }

            transitions.add(transitionChild);

            return Stack(children: transitions);
          },
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          barrierColor: barrierColor,
          barrierDismissible: barrierDismissible,
          barrierLabel: barrierLabel,
          maintainState: maintainState,
        );
}

/// Extension method for BuildContext to easily navigate with animations
extension NavigatorExtension on BuildContext {
  Future<T?> pushAnimated<T>(
    Widget page, {
    bool fadeIn = true,
    bool slideFromRight = true,
    bool slideFromBottom = false,
    bool scale = false,
    Duration duration = const Duration(milliseconds: 300),
    Duration reverseDuration = const Duration(milliseconds: 300),
  }) {
    return Navigator.of(this).push(
      AnimatedPageRoute<T>(
        page: page,
        fadeIn: fadeIn,
        slideFromRight: slideFromRight,
        slideFromBottom: slideFromBottom,
        scale: scale,
        duration: duration,
        reverseDuration: reverseDuration,
      ),
    );
  }

  Future<T?> pushReplacementAnimated<T, TO>(
    Widget page, {
    bool fadeIn = true,
    bool slideFromRight = true,
    bool slideFromBottom = false,
    bool scale = false,
    Duration duration = const Duration(milliseconds: 300),
    Duration reverseDuration = const Duration(milliseconds: 300),
    TO? result,
  }) {
    return Navigator.of(this).pushReplacement(
      AnimatedPageRoute<T>(
        page: page,
        fadeIn: fadeIn,
        slideFromRight: slideFromRight,
        slideFromBottom: slideFromBottom,
        scale: scale,
        duration: duration,
        reverseDuration: reverseDuration,
      ),
      result: result,
    );
  }
}