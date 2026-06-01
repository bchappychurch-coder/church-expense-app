import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExpenseModel {
  final String? id;
  final String userId;
  final String userName;
  final String department;
  final String purpose;
  final String description; // 필수 직접 입력 (예: "12/20 중식비")
  final int amount;
  final String receiptImageUrl;
  final String bankName;
  final String bankAccount;
  final String status; // pending | approved1 | approved | completed | rejected
  final String? approver1Id;
  final Timestamp? approver1ApprovedAt;
  final String? approver2Id;
  final Timestamp? approver2ApprovedAt;
  final String? rejectedReason;
  final Timestamp createdAt;
  final Timestamp? completedAt;

  ExpenseModel({
    this.id,
    required this.userId,
    required this.userName,
    required this.department,
    required this.purpose,
    required this.description,
    required this.amount,
    required this.receiptImageUrl,
    required this.bankName,
    required this.bankAccount,
    required this.status,
    this.approver1Id,
    this.approver1ApprovedAt,
    this.approver2Id,
    this.approver2ApprovedAt,
    this.rejectedReason,
    required this.createdAt,
    this.completedAt,
  });

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      department: data['department'] ?? '',
      purpose: data['purpose'] ?? '',
      description: data['description'] ?? '',
      amount: data['amount'] ?? 0,
      receiptImageUrl: data['receiptImageUrl'] ?? '',
      bankName: data['bankName'] ?? '',
      bankAccount: data['bankAccount'] ?? '',
      status: data['status'] ?? 'pending',
      approver1Id: data['approver1Id'],
      approver1ApprovedAt: data['approver1ApprovedAt'],
      approver2Id: data['approver2Id'],
      approver2ApprovedAt: data['approver2ApprovedAt'],
      rejectedReason: data['rejectedReason'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      completedAt: data['completedAt'],
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'department': department,
        'purpose': purpose,
        'description': description,
        'amount': amount,
        'receiptImageUrl': receiptImageUrl,
        'bankName': bankName,
        'bankAccount': bankAccount,
        'status': status,
        'approver1Id': approver1Id,
        'approver1ApprovedAt': approver1ApprovedAt,
        'approver2Id': approver2Id,
        'approver2ApprovedAt': approver2ApprovedAt,
        'rejectedReason': rejectedReason,
        'createdAt': createdAt,
        'completedAt': completedAt,
      };

  String get statusLabel {
    switch (status) {
      case 'pending':
        return '승인 대기';
      case 'approved1':
        return '1차 승인';
      case 'approved':
        return '처리 필요';
      case 'completed':
        return '송금 완료';
      case 'rejected':
        return '반려';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return const Color(0xFFD97706);
      case 'approved1':
        return const Color(0xFF7C3AED);
      case 'approved':
        return const Color(0xFF1D4ED8);
      case 'completed':
        return const Color(0xFF16A34A);
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return Colors.grey;
    }
  }

  Color get statusBgColor {
    switch (status) {
      case 'pending':
        return const Color(0xFFFEF9C3);
      case 'approved1':
        return const Color(0xFFEDE9FE);
      case 'approved':
        return const Color(0xFFEFF6FF);
      case 'completed':
        return const Color(0xFFF0FDF4);
      case 'rejected':
        return const Color(0xFFFEF2F2);
      default:
        return Colors.grey.shade100;
    }
  }

  String get formattedAmount {
    final formatted = amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '$formatted원';
  }

  String get formattedDate {
    final dt = createdAt.toDate();
    return '${dt.month}/${dt.day}';
  }
}
