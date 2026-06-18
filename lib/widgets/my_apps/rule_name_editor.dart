import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Inline name editor shown when the user taps the edit icon on a rule header.
class RuleNameEditorView extends StatefulWidget {
  final String? initialName;
  final VoidCallback onBack;
  final ValueChanged<String> onConfirm;

  const RuleNameEditorView({
    super.key,
    required this.initialName,
    required this.onBack,
    required this.onConfirm,
  });

  @override
  State<RuleNameEditorView> createState() => _RuleNameEditorViewState();
}

class _RuleNameEditorViewState extends State<RuleNameEditorView> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
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
    if (trimmed.isEmpty) return;
    HapticFeedback.mediumImpact();
    widget.onConfirm(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
          icon: Icons.arrow_back,
          onTap: widget.onBack,
        ),
        Expanded(
          child: Center(
            child: Text(
              'Name your rule',
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
        border: Border.all(
          color: AppTheme.screenTimerControllerMint.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
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
          hintText: 'e.g. Work Time',
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
            color: AppTheme.screenTimerControllerMint,
            borderRadius: BorderRadius.circular(27),
            boxShadow: [
              BoxShadow(
                color: AppTheme.screenTimerControllerMint.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'Confirm',
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
