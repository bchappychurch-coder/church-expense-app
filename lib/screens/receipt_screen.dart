import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'account_screen.dart';

class ReceiptScreen extends StatefulWidget {
  final String? initialImagePath;
  const ReceiptScreen({super.key, this.initialImagePath});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  XFile? _receiptImage;
  Uint8List? _imageBytes;
  final _amountController = TextEditingController();
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null && widget.initialImagePath!.isNotEmpty) {
      _receiptImage = XFile(widget.initialImagePath!);
      _processing = true;
      _runOcr(widget.initialImagePath!);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = kIsWeb ? await picked.readAsBytes() : null;
    setState(() {
      _receiptImage = picked;
      _imageBytes = bytes;
      _processing = true;
    });
    await _runOcr(picked.path);
  }

  Future<void> _runOcr(String path) async {
    if (mounted) setState(() => _processing = false);
  }

  bool get _canProceed =>
      !_processing &&
      _amountController.text.trim().isNotEmpty &&
      int.tryParse(_amountController.text.replaceAll(',', '')) != null &&
      int.parse(_amountController.text.replaceAll(',', '')) > 0;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            tooltip: '홈',
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepBar(current: 2),
            const SizedBox(height: 28),
            const Text('영수증 사진을 선택해 주세요',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937))),
            const SizedBox(height: 20),

            // 영수증 미리보기
            if (_receiptImage != null)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: kIsWeb && _imageBytes != null
                    ? Image.memory(_imageBytes!, fit: BoxFit.contain, width: double.infinity)
                    : Image.file(File(_receiptImage!.path), fit: BoxFit.contain, width: double.infinity),
              )
            else
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, color: Color(0xFF9CA3AF), size: 48),
                    SizedBox(height: 8),
                    Text('아래 버튼으로 영수증을 추가해주세요',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15)),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // 안내 문구
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFBBF24)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF92400E), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '카메라 앱으로 먼저 사진 찍은 후\n아래 버튼으로 사진을 선택해 주세요',
                      style: TextStyle(fontSize: 14, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library, color: Colors.white),
                label: Text(
                  _receiptImage == null ? '영수증 사진 선택' : '사진 다시 선택',
                  style: const TextStyle(fontSize: 17, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // OCR 결과 / 금액 입력
            if (_processing)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('금액을 인식하는 중...', style: TextStyle(fontSize: 16)),
                  ],
                ),
              )
            else ...[
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
                        hintStyle: TextStyle(fontSize: 18, color: Color(0xFF9CA3AF)),
                        border: InputBorder.none,
                        suffixText: '원',
                        suffixStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B7280)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_receiptImage != null)
                      const Text(
                        '금액이 맞지 않으면 직접 수정해 주세요',
                        style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // 다음 버튼
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
                            builder: (_) => AccountScreen(
                              receiptImagePath: _receiptImage?.path ?? '',
                              amount: amount,
                              xFile: _receiptImage,
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
