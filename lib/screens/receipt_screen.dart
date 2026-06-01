import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'purpose_screen.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  File? _receiptImage;
  final _amountController = TextEditingController();
  bool _processing = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() { _receiptImage = File(picked.path); _processing = true; });

    await _runOcr(picked.path);
  }

  Future<void> _runOcr(String path) async {
    try {
      final inputImage = InputImage.fromFilePath(path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
      final result = await recognizer.processImage(inputImage);
      await recognizer.close();

      final amount = _extractAmount(result.text);
      if (amount != null) {
        _amountController.text = amount;
      }
    } catch (e) {
      debugPrint('OCR 오류: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  String? _extractAmount(String text) {
    // 합계, 총액, 결제금액, 받을금액 다음에 오는 숫자 추출
    final patterns = [
      RegExp(r'(?:합\s*계|총\s*액|결제\s*금액|받을\s*금액|청구\s*금액)[^\d]*(\d[\d,]+)'),
      RegExp(r'TOTAL[^\d]*(\d[\d,]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1)!.replaceAll(',', '');
      }
    }

    // 패턴 미매칭 시 가장 큰 숫자 추출 (4자리 이상)
    final allNumbers = RegExp(r'\d[\d,]{3,}')
        .allMatches(text)
        .map((m) => int.tryParse(m.group(0)!.replaceAll(',', '')) ?? 0)
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (allNumbers.isNotEmpty) return allNumbers.first.toString();
    return null;
  }

  bool get _canProceed =>
      _receiptImage != null &&
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

            // 카메라 버튼 / 미리보기
            GestureDetector(
              onTap: _takePhoto,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: _receiptImage != null
                    ? Image.file(_receiptImage!, fit: BoxFit.cover)
                    : const Column(
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

            if (_receiptImage != null)
              TextButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 촬영하기', style: TextStyle(fontSize: 16)),
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
