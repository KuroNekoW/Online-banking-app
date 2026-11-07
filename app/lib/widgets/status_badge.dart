import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'active':
      case 'completed':
      case 'posted':
        bg = AppColors.success.withOpacity(0.12);
        fg = AppColors.success;
        label = status == 'active' ? 'Hoạt động' : 'Thành công';
        break;
      case 'draft':
      case 'pending':
      case 'pending_authentication':
      case 'processing':
      case 'pending_external':
        bg = AppColors.warning.withOpacity(0.15);
        fg = AppColors.warning;
        label = status == 'pending_authentication'
            ? 'Chờ OTP'
            : (status == 'pending_external' ? 'Chờ liên ngân hàng' : 'Đang xử lý');
        break;
      case 'failed':
      case 'rejected':
      case 'expired':
      case 'locked':
      case 'disabled':
        bg = AppColors.error.withOpacity(0.12);
        fg = AppColors.error;
        label = status == 'locked' ? 'Bị khóa' : 'Thất bại';
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
