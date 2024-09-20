import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class BottomBarAdmin extends StatefulWidget {
  final Widget child;
  final int currentPage;
  final TabController tabController;
  final List<Color> colors;
  final Color unselectedColor;
  final Color barColor;
  final double end;
  final double start;
  final ValueChanged<int> onTap;

  const BottomBarAdmin({
    required this.child,
    required this.currentPage,
    required this.tabController,
    required this.colors,
    required this.unselectedColor,
    required this.barColor,
    required this.end,
    required this.start,
    required this.onTap,
    super.key,
  });

  @override
  _BottomBarState createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBarAdmin>
    with SingleTickerProviderStateMixin {

  late ScrollController scrollBottomBarController;
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  bool isScrollingDown = false;
  bool isOnTop = true;

  @override
  void initState() {
    scrollBottomBarController = ScrollController();
    myScroll();  // Start monitoring the scroll state
    super.initState();

    // Initialize the AnimationController
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: Offset(0, widget.end),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ))..addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _controller.forward();
  }

  // Define myScroll method here
  void myScroll() {
    scrollBottomBarController.addListener(() {
      if (scrollBottomBarController.position.userScrollDirection == ScrollDirection.reverse) {
        if (!isScrollingDown) {
          isScrollingDown = true;
          hideBottomBar();
        }
      } else if (scrollBottomBarController.position.userScrollDirection == ScrollDirection.forward) {
        if (isScrollingDown) {
          isScrollingDown = false;
          showBottomBar();
        }
      }
    });
  }

  void showBottomBar() {
    if (mounted) {
      setState(() {
        _controller.forward();
      });
    }
  }

  void hideBottomBar() {
    if (mounted) {
      setState(() {
        _controller.reverse();
      });
    }
  }

  @override
  void dispose() {
    scrollBottomBarController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.bottomCenter,
      children: [
        widget.child,
        Positioned(
          bottom: widget.start,
          child: SlideTransition(
            position: _offsetAnimation,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(500),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(500),
                ),
                child: Material(
                  color: widget.barColor,
                  child: TabBar(
                    onTap: widget.onTap,
                    controller: widget.tabController,  // Ensure this matches the number of tabs.
                    indicator: UnderlineTabIndicator(
                      borderSide: BorderSide(
                        color: widget.colors[widget.currentPage],
                        width: 4,
                      ),
                      insets: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    ),
                    tabs: [
                      SizedBox(
                        height: 55,
                        width: 40,
                        child: Center(
                          child: Icon(
                            Icons.home,
                            color: widget.currentPage == 0
                                ? widget.colors[0]
                                : widget.unselectedColor,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 55,
                        width: 40,
                        child: Center(
                          child: Icon(
                            Icons.person,
                            color: widget.currentPage == 1
                                ? widget.colors[1]
                                : widget.unselectedColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}