import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../shared/app_bottom_sheet.dart';

Future<String?> showUsernameRenameSheet(
  BuildContext context, {
  required String currentName,
}) {
  return showAppBottomSheet<String>(
    context: context,
    useViewInsets: true,
    builder: (ctx) => _UsernameRenameSheet(currentName: currentName),
  );
}

class _UsernameRenameSheet extends StatefulWidget {
  final String currentName;

  const _UsernameRenameSheet({required this.currentName});

  @override
  State<_UsernameRenameSheet> createState() => _UsernameRenameSheetState();
}

class _UsernameRenameSheetState extends State<_UsernameRenameSheet> {
  static const _maxNameLength = 10;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentName.length > _maxNameLength
          ? widget.currentName.substring(0, _maxNameLength)
          : widget.currentName,
    );
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      if (_controller.text.isNotEmpty) {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _confirm() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty || trimmed.length > _maxNameLength) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            const SizedBox(height: 14),
            _buildTopBar(),
            const SizedBox(height: 28),
            _buildField(),
            const SizedBox(height: 24),
            _buildConfirmButton(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        _buildHeaderButton(
          icon: Icons.close,
          onTap: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Center(
            child: Text(
              'Edit username',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
        _buildHeaderButton(
          icon: Icons.check_rounded,
          onTap: _confirm,
        ),
      ],
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.screenTimerControllerCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLength: _maxNameLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        inputFormatters: [
          LengthLimitingTextInputFormatter(_maxNameLength),
        ],
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _confirm(),
        style: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
          decoration: TextDecoration.none,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          counterText: '',
          hintText: 'e.g. Alex',
          hintStyle: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: AppTheme.textHint,
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _confirm,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(27),
          ),
          child: Center(
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textOnAccent,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
