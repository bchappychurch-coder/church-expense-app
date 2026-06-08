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

class _ReceiptScreenState extends State<ReceiptScreen>
    with SingleTickerProviderStateMixin {
  XFile? _receiptImage;
  Uint8List? _imageBytes;
  final _amountController = TextEditingController();
  bool _processing = false;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _blinkAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(_blinkController);
    if (widget.initialImagePath != null && widget.initialImagePath!.isNotEmpty) {
      _receiptImage = XFile(widget.initialImagePath!);
      _processing = true;
      _runOcr(widget.initialImagePath!);
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
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

  void _showImageOptions() {
    final imageWidget = kIsWeb && _imageBytes != null
        ? Image.memory(_imageBytes!, fit: BoxFit.contain)
        : Image.file(File(_receiptImage!.path), fit: BoxFit.contain);

    final size = MediaQuery.of(context).size;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children: [
              // 확대 가능한 이미지
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Center(child: imageWidget),
                ),
              ),
              // 닫기 버튼
              Positioned(
                top: 40,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              // 중앙 버튼 (위아래)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, color: Colors.white, size: 16),
                      label: const Text('이 사진 쓸래요',
                          style: TextStyle(fontSize: 14, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library, color: Colors.white, size: 16),
                      label: const Text('사진 교체',
                          style: TextStyle(fontSize: 14, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pickFromGallery();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
              GestureDetector(
                onTap: _showImageOptions,
                child: Stack(
                  children: [
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF6366F1), width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: kIsWeb && _imageBytes != null
                          ? Image.memory(_imageBytes!, fit: BoxFit.contain, width: double.infinity)
                          : Image.file(File(_receiptImage!.path), fit: BoxFit.contain, width: double.infinity),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in, color: Colors.white, size: 18),
                            SizedBox(width: 4),
                            Text('눌러서 확대', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
                      '영수증 사진을 갤러리에서 선택해 주세요',
                      style: TextStyle(fontSize: 14, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            FadeTransition(
              opacity: _receiptImage == null ? _blinkAnimation : const AlwaysStoppedAnimation(1.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library, color: Colors.white, size: 26),
                  label: const Text(
                    '사진만 선택 (갤러리)',
                    style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
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
