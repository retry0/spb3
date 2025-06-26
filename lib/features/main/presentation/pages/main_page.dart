import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainPage extends StatefulWidget {
  final Widget child;

  const MainPage({super.key, required this.child});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pageController = PageController();

    // Set initial index based on current route
    _updateSelectedIndex();
  }

  // void _updateSelectedIndex() {
  //   final String location = GoRouterState.of(context).uri.path;
  //   if (location.startsWith('/home')) {
  //     setState(() => _selectedIndex = 0);
  //   } else if (location.startsWith('/spb')) {
  //     setState(() => _selectedIndex = 2);
  //   } else if (location.startsWith('/profile')) {
  //     setState(() => _selectedIndex = 3);
  //   }
  // }

  @override
  void didUpdateWidget(MainPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update selected index when route changes
    _updateSelectedIndex();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update selected index based on current route
    _updateSelectedIndex();
  }

  void _updateSelectedIndex() {
    // Only try to access GoRouterState if the context is mounted and available
    if (!mounted) return;

    try {
      final String location = GoRouterState.of(context).uri.path;
      // if (location.startsWith('/home')) {
      //   setState(() => _selectedIndex = 0);
      // }
      if (location.startsWith('/spb')) {
        setState(() => _selectedIndex = 0);
      } else if (location.startsWith('/profile')) {
        setState(() => _selectedIndex = 1);
      }
    } catch (e) {
      // If GoRouterState is not available yet, we'll try again later
      print('Could not access GoRouterState: $e');
    }
  }

  // @override
  // void didUpdateWidget(MainPage oldWidget) {
  //   super.didUpdateWidget(oldWidget);
  //   // Update selected index when route changes
  //   _updateSelectedIndex();
  // }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Add animation for page transition
    _animationController.reset();
    _animationController.forward();

    switch (index) {
      // case 0:
      //   context.go('/home');
      //   break;
      case 0:
        context.go('/spb');
        break;
      case 1:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeInOut,
              ),
            ),
            child: widget.child,
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            backgroundColor:
                Theme.of(context).brightness == Brightness.light
                    ? Colors.white
                    : Theme.of(context).colorScheme.surface,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(0.6),
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            items: [
              // BottomNavigationBarItem(
              //   icon: Icon(
              //     _selectedIndex == 0 ? Icons.home : Icons.home_outlined,
              //     size: 24,
              //   ),
              //   label: 'Home',
              // ),
              // BottomNavigationBarItem(
              //   icon: Icon(
              //     _selectedIndex == 1 ? Icons.receipt : Icons.receipt_outlined,
              //     size: 24,
              //   ),
              //   label: 'Data',
              // ),
              BottomNavigationBarItem(
                icon: Icon(
                  _selectedIndex == 0 ? Icons.receipt : Icons.receipt_outlined,
                  size: 24,
                ),
                label: 'SPB',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  _selectedIndex == 1 ? Icons.person : Icons.person_outlined,
                  size: 24,
                ),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
