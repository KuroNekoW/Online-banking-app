import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';

class OtpInputField extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  const OtpInputField({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
  });

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _getOtp() {
    return _controllers.map((c) => c.text).join();
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      // If user pasted a multi-digit string (e.g. 6 digits)
      if (value.length > 1) {
        final digits = value
            .split('')
            .where((char) => RegExp(r'[0-9]').hasMatch(char))
            .toList();
        for (int i = 0; i < widget.length && i < digits.length; i++) {
          _controllers[i].text = digits[i];
        }
        final code = _getOtp();
        widget.onChanged?.call(code);
        if (code.length == widget.length) {
          widget.onCompleted(code);
          _focusNodes.last.unfocus();
        }
        return;
      }

      // Single digit entered, move to next node
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }

    final code = _getOtp();
    widget.onChanged?.call(code);
    if (code.length == widget.length) {
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(widget.length, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == widget.length - 1 ? 0 : 8),
            child: SizedBox(
              height: 56,
              child: TextFormField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (value) => _onDigitChanged(index, value),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.divider, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.8),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
