import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/colors.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool showYesterdayButton;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.showYesterdayButton = true,
  }) : super(key: key);

  @override
  _CustomAppBarState createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(100.0);
}

class _CustomAppBarState extends State<CustomAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Timer _initialTimer;
  late Timer _repeatTimer;
  bool isScrollable = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(-1.5, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfTextOverflow().then((overflow) {
        if (overflow) {
          setState(() {
            isScrollable = true;
          });
          _startInitialAnimation();
        }
      });
    });
  }

  Future<bool> _checkIfTextOverflow() async {
    final textPainter = TextPainter(
      text: TextSpan(
          text: widget.title,
          style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.w600)),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(
        minWidth: 0, maxWidth: MediaQuery.of(context).size.width - 150);

    return textPainter.didExceedMaxLines;
  }

  void _startInitialAnimation() {
    _initialTimer = Timer(const Duration(seconds: 2), () {
      _controller.forward().then((_) {
        Future.delayed(const Duration(seconds: 2), () {
          _controller.reset();
          _startRepeatingAnimation();
        });
      });
    });
  }

  void _startRepeatingAnimation() {
    _repeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _controller.forward().then((_) {
        Future.delayed(const Duration(seconds: 2), () {
          _controller.reset();
        });
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _initialTimer.cancel();
    _repeatTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double iconSize = screenWidth * 0.07; // Dinamik icon boyutu
    double padding = screenWidth * 0.03; // Dinamik padding

    return AppBar(
      backgroundColor: colorTheme3,
      flexibleSpace: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    iconSize: iconSize,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 24.0,
                    child: ClipOval(
                      child: Image(
                        image: AssetImage('assets/logo.png'),
                        fit: BoxFit.cover,
                        width: 48.0,
                        height: 48.0,
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.black),
                      iconSize: iconSize,
                      onPressed: () {
                        Scaffold.of(context).openEndDrawer();
                      },
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.showYesterdayButton)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: padding),
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/yesterday');
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: colorTheme2,
                        foregroundColor: colorTheme5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        shadowColor: Colors.black,
                        elevation: 5,
                      ),
                      child: const Text(
                        'dün',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                const VerticalDivider(
                  color: Colors.black,
                  thickness: 1.0,
                  width: 20.0,
                  indent: 10.0,
                  endIndent: 10.0,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: isScrollable
                        ? SlideTransition(
                      position: _offsetAnimation,
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 20.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                        : Center(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 20.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(
                  color: Colors.black,
                  thickness: 1.0,
                  width: 20.0,
                  indent: 10.0,
                  endIndent: 10.0,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/calendar');
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: colorTheme2,
                      foregroundColor: colorTheme5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      shadowColor: Colors.black,
                      elevation: 5,
                    ),
                    child: const Text(
                      'takvim',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
