import 'package:flutter/material.dart';

class Modal extends StatelessWidget {
  final Animation<double> animation;
  final Function() onTap;

  const Modal({super.key, required this.animation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Visibility(
          visible: animation.value > 0,
          child: ModalBarrier(
            // 透明遮罩：仅用于“点按空白处收起展开态”，不改变背景外观
            color: Colors.transparent,
            barrierSemanticsDismissible: false,
            onDismiss: onTap,
          ),
        );
      },
    );
  }
}
