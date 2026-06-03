import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'purpose_screen.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  File? _receiptImage;
  final _amountController = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _recoverLostImage();
  }

  Future<void> _recoverLostImage() async {
    final response = await _picker.retrieveLostData();
    if (response.isEmpty || !mounted) return;
    if (response.file != null) {
      setState(() => _receiptImage = File(response.file!.path));
    }
  }

  Future<void> _takePhoto() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _receiptImage = File(picked.path));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  bool get _canProceed =>
      _receiptImage != null &&
      _amountController.text.trim().isNotEmpty &&
      (int.tryParse(_amountController.text.replaceAll(',', '')) ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        title: const Text('영수증 촬영',
            style: TextStyle(color: Colors.white, fontSize: 20)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepBar(current: 2),
            const SizedBox(height: 28),
            const Text('영수증을 촬영해 주세요',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937))),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: _takePhoto,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                constraints: const BoxConstraints(minHeight: 200),
                child: _receiptImage != null
                    ? Image.file(_receiptImage!, fit: BoxFit.contain, width: double.infinity)
                    : const SizedBox(
                        height: 200,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, color: Colors.white, size: 52),
                            SizedBox(height: 12),
                            Text('눌러서 영수증 촬영',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 18)),
                          ],
                        ),
                      ),
              ),
            ),

            if (_receiptImage != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 촬영하기', style: TextStyle(fontSize: 16)),
              ),
            ],

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3),
                border: Border.all(color: const Color(0xFFFBBF24), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('결제 금액 (원)',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937)),
                    decoration: const InputDecoration(
                      hintText: '금액을 입력해 주세요',
                      hintStyle: TextStyle(
                          fontSize: 18, color: Color(0xFF9CA3AF)),
                      border: InputBorder.none,
                      suffixText: '원',
                      suffixStyle: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B7280)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: _canProceed
                    ? () {
                        final amount = int.parse(
                            _amountController.text.replaceAll(',', ''));
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PurposeScreen(
                              receiptImagePath: _receiptImage!.path,
                              amount: amount,
                            ),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  disabledBackgroundColor: const Color(0xFFD1D5DB),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('다음',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  final int current;
  const _StepBar({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
            height: 6,
            decoration: BoxDecoration(
              color: i + 1 <= current
                  ? const Color(0xFF6366F1)
                  : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}
