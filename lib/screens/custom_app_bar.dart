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

    // Initialize the animation controller for controlling scrolling text
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    // Define the scrolling animation from the beginning to the end position
    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(-1.5, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    // Check if the text overflows after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print("Checking if text overflow occurs");
      _checkIfTextOverflow().then((overflow) {
        if (overflow) {
          print("Text overflow detected. Starting initial animation.");
          setState(() {
            isScrollable = true;
          });
          _startInitialAnimation();
        }
      });
    });
  }

  // Check if the title text overflows its container
  Future<bool> _checkIfTextOverflow() async {
    final textPainter = TextPainter(
      text: TextSpan(
          text: widget.title,
          style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.w600)),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    );

    // Calculate if the text exceeds the available width
    textPainter.layout(
        minWidth: 0, maxWidth: MediaQuery.of(context).size.width - 150);

    bool overflow = textPainter.didExceedMaxLines;
    print("Text overflow: \$overflow");
    return overflow;
  }

  // Start the initial scrolling animation after a delay
  void _startInitialAnimation() {
    print("Starting initial animation");
    _initialTimer = Timer(const Duration(seconds: 2), () {
      _controller.forward().then((_) {
        print("Initial animation completed, resetting controller");
        Future.delayed(const Duration(seconds: 2), () {
          _controller.reset();
          _startRepeatingAnimation();
        });
      });
    });
  }

  // Start a repeating animation to continuously scroll the text
  void _startRepeatingAnimation() {
    print("Starting repeating animation");
    _repeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _controller.forward().then((_) {
        print("Repeating animation cycle completed, resetting controller");
        Future.delayed(const Duration(seconds: 2), () {
          _controller.reset();
        });
      });
    });
  }

  @override
  void dispose() {
    // Dispose animation controller and cancel timers to avoid memory leaks
    print("Disposing animation controller and timers");
    _controller.dispose();
    _initialTimer.cancel();
    _repeatTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double iconSize = screenWidth * 0.07;
    double padding = screenWidth * 0.03;

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
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    iconSize: iconSize,
                    onPressed: () {
                      print("Back button pressed");
                      Navigator.pop(context);
                    },
                  ),
                  // Logo in the center
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
                  // Menu button to open the drawer
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.black),
                      iconSize: iconSize,
                      onPressed: () {
                        print("Menu button pressed");
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
                // Yesterday button
                if (widget.showYesterdayButton)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: padding),
                    child: TextButton(
                      onPressed: () {
                        print("Yesterday button pressed");
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
                // Divider between buttons
                const VerticalDivider(
                  color: Colors.black,
                  thickness: 1.0,
                  width: 20.0,
                  indent: 10.0,
                  endIndent: 10.0,
                ),
                // Title text, with scrolling if needed
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
                // Divider between buttons
                const VerticalDivider(
                  color: Colors.black,
                  thickness: 1.0,
                  width: 20.0,
                  indent: 10.0,
                  endIndent: 10.0,
                ),
                // Calendar button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: TextButton(
                    onPressed: () {
                      print("Calendar button pressed");
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
