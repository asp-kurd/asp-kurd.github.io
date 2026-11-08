import 'package:flutter/material.dart';

import '../services/backend.dart';
import '../services/progress_service.dart';
import '../ui.dart';
import 'widgets/mascot.dart';

/// 🦸 هەلبژارتنا کاراکتەری — هەڤالێ تە د هەمی وانان دا
class CharacterPickerScreen extends StatefulWidget {
  final Widget? next;
  const CharacterPickerScreen({super.key, this.next});

  @override
  State<CharacterPickerScreen> createState() => _CharacterPickerScreenState();
}

class _CharacterPickerScreenState extends State<CharacterPickerScreen> {
  late MascotChar sel = MascotChar.forUser();

  List<MascotChar> get _ordered {
    final g = Backend.instance.gender;
    final list = [...MascotChar.values];
    if (g != null) list.sort((a, b) => (a.gender == g ? 0 : 1).compareTo(b.gender == g ? 0 : 1));
    return list;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in MascotChar.values) {
        precacheImage(AssetImage(c.base), context);
        precacheImage(AssetImage(c.happy), context);
      }
    });
  }

  Future<void> _save() async {
    await ProgressService.instance.setMascot(sel.id);
    await Backend.instance.setFlag('asked_mascot');
    if (!mounted) return;
    if (widget.next != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => widget.next!));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.next == null,
          title: const Text('🦸 کاراکتەرێ خۆ هەلبژێرە'),
        ),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: MascotSays(
                key: ValueKey(sel.id),
                char: sel,
                mood: MascotMood.happy,
                height: 130,
                text: 'سلاڤ! ئەز ${sel.name}م 👋\nدێ پێکڤە فێر بین!',
              ),
            ),
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.72,
                children: [for (final c in _ordered) _tile(c)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: BigButton(label: 'ئەز ${sel.name} هەلدبژێرم', onPressed: _save),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tile(MascotChar c) {
    final on = c.id == sel.id;
    return GestureDetector(
      onTap: () => setState(() => sel = c),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: on ? AppColors.green.withValues(alpha: 0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? AppColors.green : AppColors.fg12, width: on ? 3 : 1.5),
        ),
        child: Column(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AnimatedScale(
                scale: on ? 1.06 : 1,
                duration: const Duration(milliseconds: 180),
                child: Image.asset(c.base, fit: BoxFit.contain),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Column(children: [
              Text(c.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: on ? AppColors.green : AppColors.fg)),
              Text(c.note, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColors.fg54)),
            ]),
          ),
        ]),
      ),
    );
  }
}
