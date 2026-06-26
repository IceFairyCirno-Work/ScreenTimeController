import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

/// Shared modal bottom sheet presentation used across the app.
///
/// All bottom-up sheets should use this helper so swipe-down-to-dismiss and
/// tap-outside behaviour stay consistent.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool useViewInsets = false,
  Color backgroundColor = Colors.transparent,
  Color? barrierColor,
  ShapeBorder? shape,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: backgroundColor,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.55),
    useSafeArea: true,
    enableDrag: true,
    isDismissible: isDismissible,
    showDragHandle: false,
    shape: shape,
    builder: (ctx) {
      Widget child = builder(ctx);
      if (useViewInsets) {
        child = Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: child,
        );
      }
      return Responsive.constrainedSheet(context: ctx, child: child);
    },
  );
}
