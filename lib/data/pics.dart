import 'package:flutter/material.dart';

import '../models.dart';

/// 🖼️ وێنەیێن 3D یێن پەیڤان (assets/img/vocab/<name>.webp)
/// تنێ بۆ پەیڤێن «بەرچاڤ» (تشتێن دهێنە دیتن) — پرسیارێن وێنەیی تنێ ب ڤان دهێنە کرن.
const Map<String, String> conceptPics = {
  // 🔤 ئەلفوبێ
  'abc_a': 'apple', 'abc_b': 'ball', 'abc_c': 'laptop', 'abc_f': 'fish', 'abc_g': 'guitar', 'abc_h': 'house',
  'abc_j': 'jacket', 'abc_n': 'nose', 'abc_p': 'pizza', 'abc_s': 'sun', 'abc_t': 'tomato', 'abc_v': 'bird',
  'abc_w': 'water',
  'abcen_a': 'apple', 'abcen_b': 'ball', 'abcen_c': 'cat', 'abcen_d': 'dog', 'abcen_e': 'egg', 'abcen_f': 'fish',
  'abcen_g': 'guitar', 'abcen_h': 'house', 'abcen_j': 'juice', 'abcen_k': 'key', 'abcen_m': 'moon', 'abcen_n': 'nose',
  'abcen_p': 'pizza', 'abcen_s': 'sun', 'abcen_t': 'tomato', 'abcen_w': 'water',
  'abc_ka': 'water', 'abc_kb': 'rain', 'abc_kp': 'cat', 'abc_kç': 'eye', 'abc_kx': 'house', 'abc_kd': 'tree',
  'abc_kr': 'sun', 'abc_kj': 'mother', 'abc_ks': 'apple', 'abc_kgh': 'garden', 'abc_kf': 'plane', 'abc_kq': 'pen',
  'abc_kk': 'book', 'abc_kg': 'rose', 'abc_kn': 'bread', 'abc_khh': 'horse', 'abc_ke': 'snow',
  'ab1': 'girl', 'ab2': 'cheese', 'ab4': 'oil', 'ab5': 'bridge', 'ab7': 'road', 'ab9': 'egg', 'ab12': 'book',
  'ab15': 'city', 'ab16': 'ball', 'ab18': 'bird', 'ab22': 'horse',
  // 👪 خێزان
  'a2_09': 'father', 'a2_10': 'mother', 'a2_11': 'parents', 'a2_12': 'boy', 'a2_13': 'girl', 'a2_14': 'siblings',
  // 🍞 خوارن
  'a3_01': 'bread', 'a3_02': 'cheese', 'a3_03': 'egg', 'a3_04': 'apple', 'a3_05': 'banana', 'a3_06': 'tomato',
  'a3_07': 'potato', 'a3_08': 'fish', 'a3_09': 'water', 'a3_10': 'milk', 'a3_11': 'coffee', 'a3_12': 'tea',
  'a3_13': 'juice', 'a3_19': 'checklist',
  // 🏠 خانی
  'a4_01': 'apartment', 'a4_02': 'stove', 'a4_03': 'bathtub', 'a4_04': 'bed', 'a4_05': 'sofa', 'a4_06': 'teddy',
  'a4_07': 'balcony', 'a4_17': 'chair', 'a4_18': 'bed', 'a4_19': 'wardrobe', 'a4_20': 'fridge', 'a4_21': 'lamp',
  'a6_11': 'sausage',
  // 💼 کار
  'a8_01': 'doctor', 'a8_02': 'teacher', 'a8_04': 'worker', 'a8_07': 'nurse',
  // 🏛️ ئۆفیس و ئوتێل
  'a9_03': 'passport', 'a9_04': 'idcard', 'a9_17': 'hotel', 'a9_18': 'bell', 'a9_20': 'key',
  // 🩺 لەش
  'a10_01': 'face', 'a10_02': 'eye', 'a10_03': 'ear', 'a10_04': 'nose', 'a10_05': 'tooth', 'a10_06': 'hand',
  'a10_07': 'leg', 'a10_08': 'belly',
  // 🚌 هاتنوچوون و باژێر
  'a11_09': 'bus', 'a11_10': 'train', 'a11_11': 'tram', 'a11_12': 'subway', 'a11_13': 'taxi', 'a11_14': 'plane',
  'a11_15': 'bicycle', 'a11_17': 'bank', 'a11_18': 'pharmacy', 'a11_19': 'postbox', 'a11_20': 'bakery',
  'a11_21': 'supermarket', 'a11_22': 'gasstation', 'a12_12': 'tools',
  // 👕 جل و سروشت
  'a13_01': 'tshirt', 'a13_02': 'jeans', 'a13_03': 'dress', 'a13_04': 'jacket', 'a13_05': 'shirt', 'a13_06': 'sweater',
  'a13_07': 'shoes', 'a13_08': 'socks', 'a13_21': 'mountain', 'a13_22': 'village', 'a13_23': 'sea',
  // 🎉 جەژن
  'a14_11': 'gift', 'a14_14': 'rings', 'a14_15': 'invitation',
  // 🌳 A2
  'b1_01': 'movebox', 'b2_20': 'trashbin', 'b2_30': 'stairs', 'b3_01': 'plate', 'b3_02': 'knife', 'b3_03': 'fork',
  'b3_04': 'spoon', 'b3_05': 'waterglass', 'b3_06': 'pot', 'b3_07': 'pan', 'b3_09': 'menu', 'b4_01': 'printer',
  'b4_02': 'printer', 'b5_01': 'ball', 'b5_02': 'swimmer', 'b5_03': 'cyclist', 'b5_05': 'pingpong',
  'b5_07': 'trophy', 'b5_10': 'dumbbells', 'b6_01': 'schoolhouse', 'b6_02': 'schoolhouse', 'b6_05': 'report',
  'b6_06': 'report', 'b6_07': 'gradcap', 'b6_12': 'cv', 'b6_13': 'handshake', 'b7_01': 'weddingrings',
  'b7_04': 'parents', 'b7_05': 'birthdaycake', 'b7_06': 'weddingrings', 'b7_09': 'giftbox', 'b7_11': 'bouquet',
  'b7_12': 'perfume', 'b7_13': 'necklace', 'b7_14': 'voucher', 'b9_01': 'backpack', 'b9_02': 'wallet',
  'b9_04': 'charger', 'b9_05': 'camera', 'b9_06': 'umbrella', 'b9_07': 'sunglasses', 'b9_09': 'drawer',
  'b10_01': 'charger', 'b10_02': 'smartphone', 'b10_09': 'letter', 'b10_10': 'parcel', 'b10_11': 'stamp',
  'b10_12': 'letter', 'b10_13': 'parcel', 'b10_14': 'envelope', 'b11_06': 'trafficlight', 'b11_09': 'trafficjam',
  'b11_10': 'accident', 'b11_13': 'licence', 'b11_17': 'fog', 'b11_18': 'thunderstorm', 'b11_19': 'thunderstorm',
  'b11_25': 'plane', 'b11_28': 'moped', 'b11_29': 'ticket', 'b12_02': 'mountains', 'b12_03': 'lake',
  'b12_04': 'island', 'b12_06': 'desert', 'b12_09': 'hotel', 'b12_10': 'hotel', 'b12_11': 'tent',
  'b12_17': 'suitcase', 'b12_18': 'suitcase', 'b12_21': 'airport', 'b13_02': 'atm', 'b13_03': 'atm',
  'b13_04': 'bankcard', 'b13_09': 'cash', 'b13_10': 'bankcard', 'b13_11': 'receipt', 'b13_12': 'receipt',
  'b14_01': 'teddy', 'b14_06': 'grandparents', 'b14_08': 'stroller', 'b14_22': 'trophy', 'b14_25': 'house',
  'b14_26': 'cat', 'b14_27': 'bread', 'b14_28': 'girl',
};

String? picName(WordConcept c) => conceptPics[c.id];
bool hasPic(WordConcept c) => conceptPics.containsKey(c.id);
String picAsset(String name) => 'assets/img/vocab/$name.webp';

/// وێنەیێ پەیڤێ: وێنەیێ 3D ئەگەر هەبیت، یان ئیمۆجی
class ConceptPic extends StatelessWidget {
  final WordConcept concept;
  final double size;
  const ConceptPic(this.concept, {super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final n = picName(concept);
    if (n == null) return Text(concept.pic, style: TextStyle(fontSize: size * 0.85));
    return Image.asset(picAsset(n),
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => Text(concept.pic, style: TextStyle(fontSize: size * 0.85)));
  }
}
