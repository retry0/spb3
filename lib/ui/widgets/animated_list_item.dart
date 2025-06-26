import 'package:flutter/material.dart';

/// A widget that animates its child when it appears in the list
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final bool fadeIn;
  final bool slideIn;
  final bool scaleIn;
  final Offset slideOffset;

  const AnimatedListItem({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutQuad,
    this.fadeIn = true,
    this.slideIn = true,
    this.scaleIn = false,
    this.slideOffset = const Offset(0, 0.25),
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = Tween<double>(
      begin: widget.fadeIn ? 0.0 : 1.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: widget.curve,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.slideIn ? widget.slideOffset : Offset.zero,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: widget.curve,
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: widget.scaleIn ? 0.8 : 1.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: widget.curve,
      ),
    );

    if (widget.delay == Duration.zero) {
      _animationController.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _animationController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A widget that animates a list of items with staggered animation
class StaggeredAnimatedList extends StatelessWidget {
  final List<Widget> children;
  final Duration itemDuration;
  final Duration staggerDuration;
  final Curve curve;
  final bool fadeIn;
  final bool slideIn;
  final bool scaleIn;
  final Offset slideOffset;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollController? controller;

  const StaggeredAnimatedList({
    super.key,
    required this.children,
    this.itemDuration = const Duration(milliseconds: 400),
    this.staggerDuration = const Duration(milliseconds: 50),
    this.curve = Curves.easeOutQuad,
    this.fadeIn = true,
    this.slideIn = true,
    this.scaleIn = false,
    this.slideOffset = const Offset(0, 0.25),
    this.physics,
    this.padding,
    this.shrinkWrap = false,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: physics,
      padding: padding,
      shrinkWrap: shrinkWrap,
      controller: controller,
      itemCount: children.length,
      itemBuilder: (context, index) {
        return AnimatedListItem(
          duration: itemDuration,
          delay: Duration(milliseconds: index * staggerDuration.inMilliseconds),
          curve: curve,
          fadeIn: fadeIn,
          slideIn: slideIn,
          scaleIn: scaleIn,
          slideOffset: slideOffset,
          child: children[index],
        );
      },
    );
  }
}