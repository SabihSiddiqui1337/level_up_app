import 'package:flutter/material.dart';

class AppLoadingWidget extends StatefulWidget {
  final double? size;
  
  const AppLoadingWidget({super.key, this.size});

  @override
  State<AppLoadingWidget> createState() => _AppLoadingWidgetState();
}

class _AppLoadingWidgetState extends State<AppLoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: ClipOval(
        child: Image.asset(
          'assets/app_logo.jpg',
          width: widget.size ?? 100,
          height: widget.size ?? 100,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

