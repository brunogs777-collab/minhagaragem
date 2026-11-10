// Coleção na Pista – versão 2 (redesign) – Flutter, Android + iOS
// Pacotes: flutter pub add shared_preferences image_picker path_provider mobile_scanner google_mobile_ads url_launcher share_plus
// Ajustes de Android (minSdk, AdMob, internet, nome do app e assinatura fixa) são feitos pelo workflow build-apk.yml.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ---------- Paleta (tema escuro e tema claro) ----------
class Pal {
  const Pal({
    required this.bg,
    required this.card,
    required this.card2,
    required this.line,
    required this.text,
    required this.sub,
    required this.accent,
    required this.ok,
    required this.shadow,
  });
  final Color bg, card, card2, line, text, sub, accent, ok, shadow;

  static const dark = Pal(
    bg: Color(0xFF0E0F12),
    card: Color(0xFF16181D),
    card2: Color(0xFF1E2128),
    line: Color(0xFF2B2F37),
    text: Color(0xFFF2F3F5),
    sub: Color(0xFF9AA1AD),
    accent: Color(0xFFD32030),
    ok: Color(0xFF3DBE85),
    shadow: Color(0x66000000),
  );
  static const light = Pal(
    bg: Color(0xFFF3F4F6),
    card: Color(0xFFFFFFFF),
    card2: Color(0xFFEDEFF2),
    line: Color(0xFFDDE0E6),
    text: Color(0xFF14161A),
    sub: Color(0xFF5B6270),
    accent: Color(0xFFC81D2D),
    ok: Color(0xFF1F9D63),
    shadow: Color(0x1A000000),
  );

  static Pal of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark : light;
}

const brands = ['Hot Wheels', 'Matchbox'];
const statuses = ['Tenho', 'Quero', 'Treasure Hunt'];
const conditions = ['Lacrado', 'Aberto', 'Solto'];
const carColors = <String, Color>{
  'Vermelho': Color(0xFFE5384A),
  'Azul': Color(0xFF3D7BEF),
  'Amarelo': Color(0xFFF5B91A),
  'Verde': Color(0xFF34B56A),
  'Prata': Color(0xFFC9CCD6),
  'Preto': Color(0xFF4A4A55),
  'Branco': Color(0xFFF2F2F2),
  'Laranja': Color(0xFFF26B21),
  'Roxo': Color(0xFF8B5CF6),
};

// ---------- Dados ----------
class Car {
  Car({
    required this.id,
    required this.name,
    this.code = '',
    this.toy = '',
    this.color = 'Vermelho',
    this.brand = 'Hot Wheels',
    this.status = 'Tenho',
    this.photo = '',
    this.series = '',
    this.scale = '1:64',
    this.qty = 1,
    this.fav = false,
    this.trade = false,
    this.price = '',
    this.store = '',
    this.cond = '',
    this.place = '',
    this.notes = '',
  });

  String id, name, code, toy, color, brand, status, photo, series, scale, price, store, cond, place, notes;
  int qty;
  bool fav, trade;

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'code': code, 'toy': toy, 'color': color, 'brand': brand,
        'status': status, 'photo': photo, 'series': series, 'scale': scale, 'qty': qty,
        'fav': fav, 'trade': trade, 'price': price, 'store': store, 'cond': cond,
        'place': place, 'notes': notes,
      };

  factory Car.fromJson(Map<String, dynamic> j) {
    String s(String k, [String d = '']) => (j[k] ?? d).toString();
    var status = s('status', 'Tenho');
    var qty = int.tryParse(s('qty', '1')) ?? 1;
    if (status == 'Repetido') {
      status = 'Tenho';
      if (qty < 2) qty = 2;
    }
    return Car(
      id: s('id'), name: s('name'), code: s('code'), toy: s('toy'), color: s('color', 'Vermelho'),
      brand: s('brand', 'Hot Wheels'), status: status, photo: s('photo'), series: s('series'),
      scale: s('scale', '1:64'), qty: qty < 1 ? 1 : qty, fav: j['fav'] == true, trade: j['trade'] == true,
      price: s('price'), store: s('store'), cond: s('cond'), place: s('place'), notes: s('notes'),
    );
  }
}

String csvCell(String v) => '"${v.replaceAll('"', '""')}"';

// Lê CSV/planilha colada: detecta o separador (tab, ; ou ,) e aceita aspas.
List<List<String>> parseCsv(String text) {
  final t = text.replaceFirst('\uFEFF', '');
  final first = t.split('\n').first;
  var delim = ';';
  var best = -1;
  for (final d in ['\t', ';', ',']) {
    final n = d.allMatches(first).length;
    if (n > best) {
      best = n;
      delim = d;
    }
  }
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var q = false;
  for (var i = 0; i < t.length; i++) {
    final ch = t[i];
    if (q) {
      if (ch == '"') {
        if (i + 1 < t.length && t[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          q = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      q = true;
    } else if (ch == delim) {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < t.length && t[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      cell.write(ch);
    }
  }
  row.add(cell.toString());
  if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
  return rows;
}

class Garage extends ChangeNotifier {
  final List<Car> cars = [];
  final Map<String, int> totals = {}; // total de carrinhos de cada série ("marca|série")
  SharedPreferences? _prefs;
  String docsPath = '';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    docsPath = (await getApplicationDocumentsDirectory()).path;
    final raw = _prefs!.getString('cars');
    if (raw != null) {
      cars.addAll((jsonDecode(raw) as List).map((e) => Car.fromJson(e as Map<String, dynamic>)));
    }
    final t = _prefs!.getString('totals');
    if (t != null) {
      (jsonDecode(t) as Map<String, dynamic>).forEach((k, v) => totals[k] = (v as num).toInt());
    }
  }

  // Chame depois de mudar qualquer campo de um carrinho.
  void changed() {
    _prefs?.setString('cars', jsonEncode(cars.map((c) => c.toJson()).toList()));
    _prefs?.setString('totals', jsonEncode(totals));
    notifyListeners();
  }

  void add(Car c) {
    cars.add(c);
    changed();
  }

  void remove(Car c) {
    final f = photoOf(c);
    if (f != null && f.existsSync()) f.deleteSync();
    cars.remove(c);
    changed();
  }

  void setTotal(String key, int n) {
    totals[key] = n;
    changed();
  }

  File? photoOf(Car c) => c.photo.isEmpty ? null : File('$docsPath/${c.photo}');

  // Copia a foto para a pasta do app (a original do seletor pode ser apagada pelo sistema).
  Future<String> savePhoto(XFile f) async {
    final name = 'car_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(f.path).copy('$docsPath/$name');
    return name;
  }

  // "Já tenho esse?": procura pelo código de barras ou pelo número do toy.
  Car? byCode(String v) {
    final k = v.trim().toLowerCase();
    if (k.isEmpty) return null;
    for (final c in cars) {
      if (c.status != 'Quero' && (c.code.trim().toLowerCase() == k || c.toy.trim().toLowerCase() == k)) return c;
    }
    return null;
  }

  // Resumos para a tela inicial.
  Iterable<Car> owned([String? brand]) => cars.where((c) => c.status != 'Quero' && (brand == null || c.brand == brand));
  int units([String? brand]) => owned(brand).fold(0, (s, c) => s + c.qty);

  String exportCsv() {
    const head = [
      'marca', 'nome', 'cor', 'codigo_barras', 'numero_toy', 'serie', 'escala', 'marcador',
      'quantidade', 'favorito', 'troca', 'preco', 'onde_comprou', 'estado', 'guardado_em', 'notas'
    ];
    final rows = <String>[head.join(';')];
    for (final c in cars) {
      rows.add([
        c.brand, c.name, c.color, c.code, c.toy, c.series, c.scale, c.status, '${c.qty}',
        c.fav ? 'sim' : '', c.trade ? 'sim' : '', c.price, c.store, c.cond, c.place, c.notes,
      ].map(csvCell).join(';'));
    }
    return '\uFEFF${rows.join('\r\n')}';
  }

  // Devolve [importados, que já existiam] ou null se a planilha não foi entendida.
  List<int>? importCsv(String text) {
    final rows = parseCsv(text);
    if (rows.length < 2) return null;
    final head = rows.first.map((h) => h.trim().toLowerCase()).toList();
    int ix(List<String> names) {
      for (final n in names) {
        final i = head.indexOf(n);
        if (i >= 0) return i;
      }
      return -1;
    }

    final iName = ix(['nome', 'name']);
    if (iName < 0) return null;
    final iBrand = ix(['marca', 'brand']);
    final iColor = ix(['cor', 'color']);
    final iCode = ix(['codigo_barras', 'codigo', 'código', 'barcode']);
    final iToy = ix(['numero_toy', 'toy']);
    final iSeries = ix(['serie', 'série', 'series']);
    final iScale = ix(['escala', 'scale']);
    final iStatus = ix(['marcador', 'status']);
    final iQty = ix(['quantidade', 'qtd', 'qty']);
    final iFav = ix(['favorito', 'fav']);
    final iTrade = ix(['troca']);
    final iPrice = ix(['preco', 'preço', 'price']);
    final iStore = ix(['onde_comprou', 'loja']);
    final iCond = ix(['estado', 'condicao', 'condição']);
    final iPlace = ix(['guardado_em', 'local']);
    final iNotes = ix(['notas', 'obs']);

    String g(List<String> r, int i) => i >= 0 && i < r.length ? r[i].trim() : '';
    bool yes(String v) => ['sim', 's', '1', 'true', 'x', 'yes'].contains(v.toLowerCase());
    String keyOf(String b, String n, String c, String col) => '$b|${n.toLowerCase()}|$c|${col.toLowerCase()}';

    final seen = {for (final c in cars) keyOf(c.brand, c.name, c.code, c.color)};
    var added = 0;
    var skipped = 0;
    for (final r in rows.skip(1)) {
      final name = g(r, iName);
      if (name.isEmpty) continue;
      final b = g(r, iBrand).toLowerCase().contains('match') ? 'Matchbox' : 'Hot Wheels';
      final color = g(r, iColor).isEmpty ? 'Vermelho' : g(r, iColor);
      final code = g(r, iCode);
      final key = keyOf(b, name, code, color);
      if (seen.contains(key)) {
        skipped++;
        continue;
      }
      seen.add(key);
      final st = g(r, iStatus).toLowerCase();
      var status = 'Tenho';
      if (st.contains('quero') || st.contains('desej')) status = 'Quero';
      if (st.contains('treasure') || st == 'th') status = 'Treasure Hunt';
      var qty = int.tryParse(g(r, iQty)) ?? 1;
      if (st.contains('repet') && qty < 2) qty = 2;
      cars.add(Car(
        id: '${DateTime.now().microsecondsSinceEpoch}_$added',
        name: name,
        code: code,
        toy: g(r, iToy),
        color: color,
        brand: b,
        status: status,
        series: g(r, iSeries),
        scale: g(r, iScale).isEmpty ? '1:64' : g(r, iScale),
        qty: qty < 1 ? 1 : qty,
        fav: yes(g(r, iFav)),
        trade: yes(g(r, iTrade)),
        price: g(r, iPrice),
        store: g(r, iStore),
        cond: g(r, iCond),
        place: g(r, iPlace),
        notes: g(r, iNotes),
      ));
      added++;
    }
    if (added > 0) changed();
    return [added, skipped];
  }
}

final garage = Garage();

// ---------- Tema e inicialização ----------
class ThemeCtl extends ChangeNotifier {
  bool dark = true;
  SharedPreferences? _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    dark = _p!.getBool('dark') ?? true;
  }

  void toggle() {
    dark = !dark;
    _p?.setBool('dark', dark);
    notifyListeners();
  }
}

final themeCtl = ThemeCtl();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await garage.load();
  await themeCtl.load();
  MobileAds.instance.updateRequestConfiguration(RequestConfiguration(maxAdContentRating: MaxAdContentRating.g));
  MobileAds.instance.initialize();
  runApp(const GarageApp());
}

class GarageApp extends StatelessWidget {
  const GarageApp({super.key});

  ThemeData theme(Pal p, Brightness b) {
    final base = ColorScheme.fromSeed(seedColor: p.accent, brightness: b);
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      scaffoldBackgroundColor: p.bg,
      colorScheme: base.copyWith(primary: p.accent, onPrimary: Colors.white, secondary: p.accent, surface: p.card, onSurface: p.text),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: p.card, indicatorColor: Color.lerp(p.card, p.accent, .25)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeCtl,
      builder: (context, _) => MaterialApp(
        title: 'Coleção na Pista',
        debugShowCheckedModeBanner: false,
        theme: theme(Pal.light, Brightness.light),
        darkTheme: theme(Pal.dark, Brightness.dark),
        themeMode: themeCtl.dark ? ThemeMode.dark : ThemeMode.light,
        home: const Shell(),
      ),
    );
  }
}

// ---------- Utilidades e componentes reutilizáveis ----------
TextStyle ts(Color c, double s, [FontWeight w = FontWeight.w600]) => TextStyle(color: c, fontSize: s, fontWeight: w);

void go(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

void snack(BuildContext context, String t) {
  final p = Pal.of(context);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: p.card2,
    content: Text(t, style: TextStyle(color: p.text)),
  ));
}

Color tint(Pal p, Color c) => Color.lerp(p.card2, c, p.bg.computeLuminance() < .5 ? .22 : .30)!;

InputDecoration field(Pal p, String hint, [IconData? icon]) {
  OutlineInputBorder b(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: p.sub),
    prefixIcon: icon == null ? null : Icon(icon, color: p.sub),
    filled: true,
    fillColor: p.card2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: b(p.line),
    enabledBorder: b(p.line),
    focusedBorder: b(p.accent, 1.6),
  );
}

Widget fieldLabel(Pal p, String t) =>
    Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(t, style: ts(p.sub, 12.5, FontWeight.w700)));

Widget input(Pal p, TextEditingController c, String hint, {int lines = 1, TextInputType? type}) =>
    TextField(controller: c, minLines: lines, maxLines: lines, keyboardType: type, decoration: field(p, hint));

Widget iconBtn(Pal p, IconData i, VoidCallback? f, {String? tip, bool accent = false}) => IconButton(
      tooltip: tip,
      onPressed: f,
      style: IconButton.styleFrom(
        backgroundColor: accent ? p.accent : p.card2,
        foregroundColor: accent ? Colors.white : p.text,
        disabledBackgroundColor: p.card2,
        minimumSize: const Size(44, 44),
      ),
      icon: Icon(i, size: 22),
    );

Widget primary(Pal p, String text, VoidCallback? onPressed, {IconData? icon}) {
  final style = FilledButton.styleFrom(
    backgroundColor: p.accent,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
  );
  return icon == null
      ? FilledButton(style: style, onPressed: onPressed, child: Text(text))
      : FilledButton.icon(style: style, onPressed: onPressed, icon: Icon(icon, size: 20), label: Text(text));
}

Widget ghost(Pal p, String text, VoidCallback? onPressed, {IconData? icon}) {
  final style = OutlinedButton.styleFrom(
    foregroundColor: p.text,
    side: BorderSide(color: p.line, width: 1.5),
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
  );
  return icon == null
      ? OutlinedButton(style: style, onPressed: onPressed, child: Text(text))
      : OutlinedButton.icon(style: style, onPressed: onPressed, icon: Icon(icon, size: 20), label: Text(text));
}

Widget smallBtn(Pal p, String text, VoidCallback onPressed, {IconData? icon, bool filled = false}) {
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  const pad = EdgeInsets.symmetric(horizontal: 8);
  final child = Row(mainAxisSize: MainAxisSize.min, children: [
    if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 4)],
    Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
  ]);
  return filled
      ? FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              padding: pad,
              shape: shape,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          onPressed: onPressed,
          child: child)
      : OutlinedButton(
          style: OutlinedButton.styleFrom(
              foregroundColor: p.text,
              side: BorderSide(color: p.line, width: 1.5),
              minimumSize: const Size(0, 40),
              padding: pad,
              shape: shape,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          onPressed: onPressed,
          child: child);
}

Widget sectionTitle(Pal p, String t, [int? n]) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(children: [
        Text(t, style: ts(p.text, 16, FontWeight.w800)),
        if (n != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(10)),
            child: Text('$n', style: ts(p.sub, 12, FontWeight.w800)),
          ),
        ],
      ]),
    );

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.onLongPress, this.radius = 20});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap, onLongPress;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: p.line),
        boxShadow: [BoxShadow(color: p.shadow, blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, onLongPress: onLongPress, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

class PillChip extends StatelessWidget {
  const PillChip(this.label, {super.key, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final fg = selected ? Colors.white : p.text;
    return Material(
      color: selected ? p.accent : p.card2,
      shape: StadiumBorder(side: BorderSide(color: selected ? p.accent : p.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
            Text(label, style: ts(fg, 13, FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: Colors.white), const SizedBox(width: 3)],
        Text(text, style: ts(Colors.white, 11.5, FontWeight.w800)),
      ]),
    );
  }
}

class BrandSwitch extends StatelessWidget {
  const BrandSwitch({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
      child: Row(children: [
        for (final b in brands)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(b),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: b == value ? p.accent : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                child: Text(b, style: ts(b == value ? Colors.white : p.sub, 14, FontWeight.w800)),
              ),
            ),
          ),
      ]),
    );
  }
}

class Bar extends StatelessWidget {
  const Bar(this.value, {super.key, this.height = 8});
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(value: v, minHeight: height, color: p.accent, backgroundColor: p.card2),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title, text;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: p.card2, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: p.sub),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: ts(p.text, 17, FontWeight.w800)),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: ts(p.sub, 13.5)),
        ]),
      ),
    );
  }
}

class LogoMark extends StatelessWidget {
  const LogoMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF7E1019), Pal.of(context).accent]),
      ),
      alignment: Alignment.center,
      child: CustomPaint(size: const Size(28, 14), painter: CarPainter(Colors.white, const Color(0xFF7E1019))),
    );
  }
}

// Silhueta do carrinho (usada quando não há foto).
class CarPainter extends CustomPainter {
  CarPainter(this.color, this.wheel);
  final Color color, wheel;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 96, size.height / 48);
    final body = Path()
      ..moveTo(4, 34)
      ..relativeLineTo(0, -7)
      ..relativeCubicTo(0, -3, 2, -5, 6, -6)
      ..relativeLineTo(14, -3)
      ..relativeLineTo(9, -9)
      ..relativeCubicTo(2, -2, 4, -3, 7, -3)
      ..relativeLineTo(20, 0)
      ..relativeCubicTo(3, 0, 5, 1, 7, 3)
      ..relativeLineTo(7, 8)
      ..relativeLineTo(12, 3)
      ..relativeCubicTo(3, 1, 5, 3, 5, 6)
      ..relativeLineTo(0, 8)
      ..close();
    final glass = Path()
      ..moveTo(31, 18)
      ..relativeLineTo(6, -7)
      ..relativeCubicTo(1, -1, 2, -1, 3, -1)
      ..relativeLineTo(7, 0)
      ..relativeLineTo(0, 8)
      ..close()
      ..moveTo(51, 10)
      ..relativeLineTo(9, 0)
      ..relativeCubicTo(1, 0, 2, 0, 3, 1)
      ..relativeLineTo(5, 7)
      ..lineTo(51, 18)
      ..close();
    canvas.drawPath(body, Paint()..color = color);
    canvas.drawPath(glass, Paint()..color = const Color(0xB30B0B0F));
    for (final x in [26.0, 72.0]) {
      canvas.drawCircle(Offset(x, 34), 8, Paint()..color = wheel);
      canvas.drawCircle(
          Offset(x, 34), 8, Paint()..color = const Color(0xFF9A9AAA)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(CarPainter old) => old.color != color || old.wheel != wheel;
}

// Faixas diagonais discretas usadas no cartão de resumo.
class StripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x14FFFFFF);
    for (var i = 0; i < 4; i++) {
      final x0 = size.width * .52 + i * 46;
      final path = Path()
        ..moveTo(x0 + 70, 0)
        ..lineTo(x0 + 100, 0)
        ..lineTo(x0 + 30, size.height)
        ..lineTo(x0, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(StripesPainter old) => false;
}

// Mostra a foto do carrinho; sem foto, desenha a silhueta.
class CarImage extends StatelessWidget {
  const CarImage({super.key, required this.car, this.silhouette = const Size(96, 48)});
  final Car car;
  final Size silhouette;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = carColors[car.color] ?? p.sub;
    final fallback = Container(
      color: tint(p, c),
      alignment: Alignment.center,
      child: CustomPaint(size: silhouette, painter: CarPainter(c, p.bg)),
    );
    final f = garage.photoOf(car);
    if (f == null) return fallback;
    return Image.file(f, fit: BoxFit.cover, width: double.infinity, height: double.infinity, cacheWidth: 700, errorBuilder: (_, __, ___) => fallback);
  }
}

// Banner do AdMob. Os IDs abaixo são de TESTE do Google: troque pelos seus antes de publicar.
const bannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
const bannerIos = 'ca-app-pub-3940256099942544/2934735716';

class AdSlot extends StatefulWidget {
  const AdSlot({super.key});

  @override
  State<AdSlot> createState() => _AdSlotState();
}

class _AdSlotState extends State<AdSlot> {
  BannerAd? ad;
  bool loaded = false;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    ad = BannerAd(
      adUnitId: Platform.isAndroid ? bannerAndroid : bannerIos,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => loaded = true);
        },
        onAdFailedToLoad: (bad, error) {
          bad.dispose();
          ad = null;
          if (mounted) setState(() => failed = true);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final a = ad;
    if (failed || a == null) return const SizedBox.shrink(); // sem anúncio, sem espaço vazio
    if (!loaded) return Container(height: 58, color: p.bg); // reserva o espaço enquanto carrega
    return Container(
      color: p.bg,
      alignment: Alignment.center,
      height: a.size.height.toDouble() + 8,
      child: SizedBox(width: a.size.width.toDouble(), height: a.size.height.toDouble(), child: AdWidget(ad: a)),
    );
  }
}

// ---------- Afiliados (botão Comprar) ----------
// Troque SEU_CODIGO pelo seu código de afiliado ao entrar num programa (o formato abaixo é o da Amazon).
// Sem código, o link funciona como uma busca comum, mas não gera comissão.
const affiliateSearch = 'https://www.amazon.com.br/s?k={q}&tag=SEU_CODIGO';

Future<void> openStore(BuildContext context, Car c) async {
  final url = affiliateSearch.replaceAll('{q}', Uri.encodeQueryComponent('${c.brand} ${c.name}'));
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) snack(context, 'Não foi possível abrir a loja');
}

// ---------- Backup, planilha e compartilhamento ----------
Future<void> exportBackup(BuildContext context) async {
  if (garage.cars.isEmpty) {
    snack(context, 'Ainda não há nada para exportar');
    return;
  }
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/colecao-na-pista.csv');
  await f.writeAsString(garage.exportCsv());
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'text/csv')]));
}

String tradeText(String brand) {
  final trade = garage.cars.where((c) => c.brand == brand && c.status != 'Quero' && c.trade).toList();
  final wants = garage.cars.where((c) => c.brand == brand && c.status == 'Quero').toList();
  String line(Car c) {
    final qty = c.qty > 1 ? ' x${c.qty}' : '';
    final series = c.series.isEmpty ? '' : ' - ${c.series}';
    return '- ${c.name} (${c.color})$qty$series';
  }

  final b = StringBuffer('Coleção na Pista - $brand\n');
  if (trade.isNotEmpty) {
    b.writeln('\nPara troca ou venda:');
    for (final c in trade) {
      b.writeln(line(c));
    }
  }
  if (wants.isNotEmpty) {
    b.writeln('\nProcuro:');
    for (final c in wants) {
      b.writeln(line(c));
    }
  }
  return b.toString();
}

Future<bool> confirmDelete(BuildContext context, Car car) async {
  final p = Pal.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      title: Text('Remover ${car.name}?', style: ts(p.text, 18, FontWeight.w800)),
      content: Text('Essa ação não pode ser desfeita.', style: ts(p.sub, 14)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: TextStyle(color: p.sub))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Remover', style: TextStyle(color: p.accent, fontWeight: FontWeight.w800))),
      ],
    ),
  );
  if (ok == true) garage.remove(car);
  return ok == true;
}
// ---------- Estrutura principal ----------
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  String brand = brands.first;
  static const titles = ['Início', 'Minha coleção', 'Lista de desejos', 'Trocas e vendas'];

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final pages = <Widget>[
      HomeView(
        brand: brand,
        onTab: (i) => setState(() => tab = i),
        onBrand: (b) => setState(() {
          brand = b;
          tab = 1;
        }),
      ),
      CollectionView(brand: brand),
      WishlistView(brand: brand),
      TradeView(brand: brand),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
            child: Row(children: [
              const LogoMark(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('COLEÇÃO NA PISTA',
                      style: TextStyle(color: p.accent, fontSize: 11, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 2.2)),
                  Text(titles[tab], maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.text, 22, FontWeight.w800)),
                ]),
              ),
              iconBtn(p, Icons.qr_code_scanner, () => go(context, CheckPage(brand: brand, autoScan: true)), tip: 'Já tenho esse?', accent: true),
              const SizedBox(width: 6),
              iconBtn(p, themeCtl.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, themeCtl.toggle, tip: 'Alternar tema'),
              PopupMenuButton<String>(
                tooltip: 'Mais',
                color: p.card2,
                icon: Icon(Icons.more_vert, color: p.text),
                onSelected: (v) {
                  if (v == 'series') go(context, SeriesPage(brand: brand));
                  if (v == 'export') exportBackup(context);
                  if (v == 'import') go(context, const ImportPage());
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'series', child: Text('Séries e progresso')),
                  PopupMenuItem(value: 'export', child: Text('Exportar planilha (backup)')),
                  PopupMenuItem(value: 'import', child: Text('Importar planilha')),
                ],
              ),
            ]),
          ),
          if (tab != 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: BrandSwitch(value: brand, onChanged: (b) => setState(() => brand = b)),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
            ),
          ),
        ]),
      ),
      floatingActionButton: tab == 3
          ? null
          : FloatingActionButton.extended(
              backgroundColor: p.accent,
              foregroundColor: Colors.white,
              onPressed: () => go(context, CarFormPage(brand: brand, status: tab == 2 ? 'Quero' : 'Tenho')),
              icon: const Icon(Icons.add),
              label: const Text('Novo', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const AdSlot(),
        NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Início'),
            NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Coleção'),
            NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Desejos'),
            NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Trocas'),
          ],
        ),
      ]),
    );
  }
}

// ---------- Início ----------
class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.brand, required this.onTab, required this.onBrand});
  final String brand;
  final void Function(int) onTab;
  final void Function(String) onBrand;

  Widget stat(String n, String l) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(n, style: ts(Colors.white, 15, FontWeight.w900)),
          const SizedBox(width: 6),
          Text(l, style: ts(const Color(0xDDFFFFFF), 12.5)),
        ]),
      );

  Widget brandCard(Pal p, String b) {
    final units = garage.units(b);
    final total = garage.units();
    return Expanded(
      child: AppCard(
        onTap: () => onBrand(b),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(b, style: ts(p.text, 14, FontWeight.w800))),
            Icon(Icons.chevron_right, size: 20, color: p.sub),
          ]),
          const SizedBox(height: 10),
          Text('$units', style: ts(p.text, 30, FontWeight.w900)),
          Text('${garage.owned(b).length} modelos', style: ts(p.sub, 12)),
          const SizedBox(height: 10),
          Bar(total == 0 ? 0.0 : units / total, height: 6),
        ]),
      ),
    );
  }

  Widget tile(Pal p, IconData icon, String label, VoidCallback onTap) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(8),
        radius: 18,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: Color.lerp(p.card, p.accent, .16), shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: p.accent),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, maxLines: 2, style: ts(p.text, 12, FontWeight.w700)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: garage,
      builder: (context, _) {
        final p = Pal.of(context);
        final owned = garage.owned().toList();
        final units = garage.units();
        final favs = owned.where((c) => c.fav).length;
        final ths = owned.where((c) => c.status == 'Treasure Hunt').length;
        final reps = owned.where((c) => c.qty > 1).length;
        final recent = owned.reversed.take(8).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7E1019), Color(0xFFD32030)]),
            ),
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: StripesPainter())),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SUA COLEÇÃO', style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.4)),
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$units', style: const TextStyle(color: Colors.white, fontSize: 56, height: 1, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                    const SizedBox(width: 10),
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(units == 1 ? 'miniatura' : 'miniaturas', style: ts(Colors.white, 16, FontWeight.w700))),
                  ]),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    stat('${owned.length}', 'modelos'),
                    stat('$favs', 'favoritos'),
                    stat('$ths', 'Treasure Hunt'),
                    stat('$reps', 'repetidos'),
                  ]),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [brandCard(p, brands[0]), const SizedBox(width: 12), brandCard(p, brands[1])]),
          sectionTitle(p, 'Acesso rápido'),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [
              tile(p, Icons.add, 'Novo carrinho', () => go(context, CarFormPage(brand: brand))),
              tile(p, Icons.qr_code_scanner, 'Já tenho esse?', () => go(context, CheckPage(brand: brand, autoScan: true))),
              tile(p, Icons.flag_outlined, 'Séries', () => go(context, SeriesPage(brand: brand))),
              tile(p, Icons.swap_horiz, 'Trocas', () => onTab(3)),
              tile(p, Icons.file_upload_outlined, 'Exportar', () => exportBackup(context)),
              tile(p, Icons.file_download_outlined, 'Importar', () => go(context, const ImportPage())),
            ],
          ),
          if (recent.isNotEmpty) ...[
            sectionTitle(p, 'Adicionados recentemente'),
            SizedBox(
              height: 172,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => SizedBox(
                  width: 130,
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    radius: 18,
                    onTap: () => go(context, CarFormPage(car: recent[i])),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: SizedBox(width: double.infinity, child: CarImage(car: recent[i], silhouette: const Size(70, 35)))),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(recent[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.text, 13, FontWeight.w800)),
                          Text(recent[i].brand, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.sub, 11.5)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ],
          if (owned.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: AppCard(
                child: Text('Toque em Novo para cadastrar o primeiro carrinho da sua coleção.', style: ts(p.sub, 14)),
              ),
            ),
        ]);
      },
    );
  }
}

// ---------- Minha coleção ----------
class CollectionView extends StatefulWidget {
  const CollectionView({super.key, required this.brand});
  final String brand;

  @override
  State<CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<CollectionView> {
  final ctl = TextEditingController();
  String query = '';
  String? filter; // null = Todos
  static const filters = <String?>[null, 'Favoritos', 'Repetidos', 'Treasure Hunt', 'Troca'];

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  bool passes(Car c) {
    switch (filter) {
      case 'Favoritos':
        return c.fav;
      case 'Repetidos':
        return c.qty > 1;
      case 'Treasure Hunt':
        return c.status == 'Treasure Hunt';
      case 'Troca':
        return c.trade;
      default:
        return true;
    }
  }

  IconData? filterIcon(String? f) {
    switch (f) {
      case 'Favoritos':
        return Icons.favorite;
      case 'Repetidos':
        return Icons.layers_outlined;
      case 'Treasure Hunt':
        return Icons.star_rounded;
      case 'Troca':
        return Icons.swap_horiz;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: garage,
      builder: (context, _) {
        final p = Pal.of(context);
        final q = query.toLowerCase();
        final all = garage.owned(widget.brand).toList();
        final mine = all
            .where((c) => passes(c) && (q.isEmpty || '${c.name} ${c.color} ${c.code} ${c.toy} ${c.series} ${c.notes}'.toLowerCase().contains(q)))
            .toList()
            .reversed
            .toList(); // mais novos primeiro
        final list = [...mine.where((c) => c.fav), ...mine.where((c) => !c.fav)]; // favoritos na frente
        final units = all.fold<int>(0, (s, c) => s + c.qty);
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: ctl,
              onChanged: (v) => setState(() => query = v),
              decoration: field(p, 'Buscar nome, série, código...', Icons.search).copyWith(
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, color: p.sub),
                        onPressed: () {
                          ctl.clear();
                          setState(() => query = '');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PillChip(f ?? 'Todos', selected: filter == f, icon: filterIcon(f), onTap: () => setState(() => filter = f)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${list.length} de ${all.length} modelos · $units unidades', style: ts(p.sub, 12.5)),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(
                    icon: Icons.directions_car_outlined,
                    title: all.isEmpty ? 'Sua coleção está vazia' : 'Nada encontrado',
                    text: all.isEmpty ? 'Toque em Novo para cadastrar o primeiro carrinho.' : 'Tente outra busca ou outro filtro.')
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.70),
                    itemCount: list.length,
                    itemBuilder: (_, i) => CarCard(car: list[i]),
                  ),
          ),
        ]);
      },
    );
  }
}

class FavButton extends StatelessWidget {
  const FavButton({super.key, required this.car});
  final Car car;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Favorito',
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(backgroundColor: const Color(0x66000000)),
      onPressed: () {
        car.fav = !car.fav;
        garage.changed();
      },
      icon: AnimatedScale(
        scale: car.fav ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Icon(car.fav ? Icons.favorite : Icons.favorite_border, size: 20, color: car.fav ? const Color(0xFFFF6B77) : Colors.white),
      ),
    );
  }
}

class CarCard extends StatelessWidget {
  const CarCard({super.key, required this.car});
  final Car car;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final id = car.code.isNotEmpty ? car.code : car.toy;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => go(context, CarFormPage(car: car)),
      onLongPress: () => confirmDelete(context, car),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: CarImage(car: car, silhouette: const Size(110, 55))),
            Positioned(
              top: 8,
              left: 8,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (car.status == 'Treasure Hunt') Tag('Treasure Hunt', color: p.accent, icon: Icons.star_rounded),
                if (car.qty > 1) ...[const SizedBox(height: 4), Tag('×${car.qty}', color: const Color(0xFF3A4150))],
                if (car.trade) ...[const SizedBox(height: 4), Tag('Troca', color: const Color(0xFF3A4150), icon: Icons.swap_horiz)],
              ]),
            ),
            Positioned(top: 2, right: 2, child: FavButton(car: car)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(car.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.text, 15, FontWeight.w800)),
            const SizedBox(height: 2),
            Text(car.series.isEmpty ? car.brand : '${car.brand} · ${car.series}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.sub, 12)),
            if (id.isNotEmpty)
              Text(id, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.sub, fontSize: 11, fontFamily: 'monospace', letterSpacing: .4)),
          ]),
        ),
      ]),
    );
  }
}

// ---------- Lista de desejos ----------
class WishCard extends StatelessWidget {
  const WishCard({super.key, required this.car});
  final Car car;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => go(context, CarFormPage(car: car)),
      child: Column(children: [
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(width: 76, height: 76, child: CarImage(car: car, silhouette: const Size(56, 28))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(car.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(p.text, 16, FontWeight.w800)),
              const SizedBox(height: 2),
              Text(car.series.isEmpty ? car.brand : '${car.brand} · ${car.series}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.sub, 12.5)),
              Text(car.color, style: ts(p.sub, 12.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: smallBtn(p, 'Editar', () => go(context, CarFormPage(car: car)), icon: Icons.edit_outlined)),
          const SizedBox(width: 8),
          Expanded(child: smallBtn(p, 'Comprar', () => openStore(context, car), icon: Icons.shopping_bag_outlined)),
          const SizedBox(width: 8),
          Expanded(
            child: smallBtn(p, 'Adquirido', () {
              car.status = 'Tenho';
              garage.changed();
            }, icon: Icons.check_circle_outline, filled: true),
          ),
        ]),
      ]),
    );
  }
}

class WishlistView extends StatelessWidget {
  const WishlistView({super.key, required this.brand});
  final String brand;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: garage,
      builder: (context, _) {
        final p = Pal.of(context);
        final list = garage.cars.where((c) => c.brand == brand && c.status == 'Quero').toList();
        if (list.isEmpty) {
          return const EmptyState(
              icon: Icons.favorite_border, title: 'Sua lista está vazia', text: 'Toque em Novo para adicionar os carrinhos que você procura.');
        }
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 2),
            child: Text('${list.length} procurados · links de lojas parceiras podem gerar comissão para o app.', style: ts(p.sub, 12)),
          ),
          for (final c in list) Padding(padding: const EdgeInsets.only(bottom: 12), child: WishCard(car: c)),
        ]);
      },
    );
  }
}

// ---------- Trocas e vendas ----------
class CarTile extends StatelessWidget {
  const CarTile({super.key, required this.car, this.trailing, this.onTap});
  final Car car;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AppCard(
      padding: const EdgeInsets.all(10),
      radius: 18,
      onTap: onTap,
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 64, height: 64, child: CarImage(car: car, silhouette: const Size(48, 24))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(car.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.text, 15, FontWeight.w800)),
            Text(car.series.isEmpty ? car.color : '${car.color} · ${car.series}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.sub, 12.5)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class TradeView extends StatelessWidget {
  const TradeView({super.key, required this.brand});
  final String brand;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: garage,
      builder: (context, _) {
        final p = Pal.of(context);
        final trade = garage.cars.where((c) => c.brand == brand && c.status != 'Quero' && c.trade).toList();
        final wants = garage.cars.where((c) => c.brand == brand && c.status == 'Quero').toList();
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: [
          primary(p, 'Compartilhar lista (WhatsApp e outros)', () {
            if (trade.isEmpty && wants.isEmpty) {
              snack(context, 'Marque carrinhos para troca ou adicione itens à lista de desejos');
              return;
            }
            SharePlus.instance.share(ShareParams(text: tradeText(brand)));
          }, icon: Icons.share),
          sectionTitle(p, 'Para troca ou venda', trade.length),
          if (trade.isEmpty)
            AppCard(child: Text('Abra um carrinho e ligue "Disponível para troca ou venda".', style: ts(p.sub, 13.5)))
          else
            for (final c in trade)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CarTile(
                  car: c,
                  onTap: () => go(context, CarFormPage(car: c)),
                  trailing: c.qty > 1 ? Tag('×${c.qty}', color: const Color(0xFF3A4150)) : null,
                ),
              ),
          sectionTitle(p, 'Procuro', wants.length),
          if (wants.isEmpty)
            AppCard(child: Text('Sua lista de desejos está vazia.', style: ts(p.sub, 13.5)))
          else
            for (final c in wants)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CarTile(car: c, onTap: () => go(context, CarFormPage(car: c))),
              ),
        ]);
      },
    );
  }
}
// ---------- Séries e progresso ----------
class SeriesPage extends StatelessWidget {
  const SeriesPage({super.key, required this.brand});
  final String brand;

  Future<void> editTotal(BuildContext context, String key, int current) async {
    final p = Pal.of(context);
    final ctl = TextEditingController(text: '$current');
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        title: Text('Quantos carrinhos tem a série?', style: ts(p.text, 18, FontWeight.w800)),
        content: TextField(controller: ctl, keyboardType: TextInputType.number, autofocus: true, decoration: field(p, 'Total da série')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: p.sub))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(ctl.text.trim())),
              child: Text('Salvar', style: TextStyle(color: p.accent, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (n != null && n > 0) garage.setTotal(key, n);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Séries · $brand', style: ts(p.text, 20, FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: garage,
        builder: (context, _) {
          final names = <String>{};
          for (final c in garage.cars) {
            if (c.brand == brand && c.series.trim().isNotEmpty) names.add(c.series.trim());
          }
          if (names.isEmpty) {
            return const EmptyState(
                icon: Icons.flag_outlined,
                title: 'Nenhuma série ainda',
                text: 'Preencha o campo "Série" nos carrinhos para acompanhar o progresso de cada série.');
          }
          final list = names.toList()..sort();
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final s = list[i];
              final inSeries = garage.cars.where((c) => c.brand == brand && c.series.trim() == s);
              final owned = inSeries.where((c) => c.status != 'Quero').length;
              final wanted = inSeries.where((c) => c.status == 'Quero').length;
              final key = '$brand|$s';
              final total = garage.totals[key] ?? (owned + wanted);
              final frac = total == 0 ? 0.0 : (owned / total).clamp(0.0, 1.0).toDouble();
              return AppCard(
                onTap: () => editTotal(context, key, total),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(s, style: ts(p.text, 16, FontWeight.w800))),
                    Text('${(frac * 100).round()}%', style: ts(p.accent, 18, FontWeight.w900)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Você tem $owned de $total', style: ts(p.sub, 13)),
                  const SizedBox(height: 12),
                  Bar(frac, height: 10),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.edit_outlined, size: 14, color: p.sub),
                    const SizedBox(width: 6),
                    Text('Toque para informar o total da série', style: ts(p.sub, 12)),
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------- Cadastro e edição ----------
class CarFormPage extends StatefulWidget {
  const CarFormPage({super.key, this.car, this.brand = 'Hot Wheels', this.status = 'Tenho', this.code = '', this.toy = ''});
  final Car? car; // null = novo carrinho
  final String brand, status, code, toy;

  @override
  State<CarFormPage> createState() => _CarFormPageState();
}

class _CarFormPageState extends State<CarFormPage> {
  late final Car? car = widget.car;
  late final name = TextEditingController(text: car?.name ?? '');
  late final code = TextEditingController(text: car?.code ?? widget.code);
  late final toy = TextEditingController(text: car?.toy ?? widget.toy);
  late final series = TextEditingController(text: car?.series ?? '');
  late final scale = TextEditingController(text: car?.scale ?? '1:64');
  late final price = TextEditingController(text: car?.price ?? '');
  late final store = TextEditingController(text: car?.store ?? '');
  late final place = TextEditingController(text: car?.place ?? '');
  late final notes = TextEditingController(text: car?.notes ?? '');
  late String brand = car?.brand ?? widget.brand;
  late String color = car?.color ?? carColors.keys.first;
  late String status = car?.status ?? widget.status;
  late String cond = car?.cond ?? '';
  late int qty = car?.qty ?? 1;
  late bool fav = car?.fav ?? false;
  late bool trade = car?.trade ?? false;
  XFile? picked;

  @override
  void dispose() {
    for (final c in [name, code, toy, series, scale, price, store, place, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pick(ImageSource source) async {
    try {
      final f = await ImagePicker().pickImage(source: source, maxWidth: 1280, imageQuality: 85);
      if (f != null && mounted) setState(() => picked = f);
    } catch (_) {
      if (mounted) snack(context, 'Não foi possível abrir a câmera ou a galeria');
    }
  }

  Future<void> scan() async {
    final v = await scanCode(context);
    if (v != null && mounted) setState(() => code.text = v);
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      snack(context, 'Dê um nome ao carrinho');
      return;
    }
    final pk = picked;
    final photo = pk == null ? null : await garage.savePhoto(pk);
    final c = car ?? Car(id: DateTime.now().microsecondsSinceEpoch.toString(), name: '');
    if (photo != null) {
      final old = garage.photoOf(c);
      if (old != null && old.existsSync()) old.deleteSync();
      c.photo = photo;
    }
    c.name = name.text.trim();
    c.code = code.text.trim();
    c.toy = toy.text.trim();
    c.series = series.text.trim();
    c.scale = scale.text.trim();
    c.price = price.text.trim();
    c.store = store.text.trim();
    c.place = place.text.trim();
    c.notes = notes.text.trim();
    c.brand = brand;
    c.color = color;
    c.status = status;
    c.cond = cond;
    c.qty = qty;
    c.fav = fav;
    c.trade = trade;
    if (car == null) {
      garage.add(c);
    } else {
      garage.changed();
    }
    if (mounted) Navigator.pop(context);
  }

  Widget section(Pal p, String title, IconData icon, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 18, color: p.accent),
              const SizedBox(width: 8),
              Text(title, style: ts(p.text, 15, FontWeight.w800)),
            ]),
            ...children,
          ]),
        ),
      );

  Widget colorDots(Pal p) => Wrap(spacing: 12, runSpacing: 12, children: [
        for (final e in carColors.entries)
          GestureDetector(
            onTap: () => setState(() => color = e.key),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: e.value,
                  shape: BoxShape.circle,
                  border: Border.all(color: color == e.key ? p.accent : p.line, width: color == e.key ? 3 : 1),
                ),
              ),
              const SizedBox(height: 4),
              Text(e.key, style: ts(color == e.key ? p.text : p.sub, 10.5, FontWeight.w700)),
            ]),
          ),
      ]);

  Widget switchRow(Pal p, String title, String sub, bool v, ValueChanged<bool> f) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: ts(p.text, 14.5, FontWeight.w700)),
              Text(sub, style: ts(p.sub, 12)),
            ]),
          ),
          Switch(value: v, onChanged: f),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final existing = car == null ? null : garage.photoOf(car!);
    final Widget empty = Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.photo_camera_outlined, size: 44, color: p.sub),
        const SizedBox(height: 8),
        Text('Adicione uma foto do carrinho', style: ts(p.sub, 13)),
      ]),
    );
    final Widget preview = picked != null
        ? Image.file(File(picked!.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
        : existing != null
            ? Image.file(existing, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => empty)
            : empty;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(car == null ? 'Novo carrinho' : 'Editar carrinho', style: ts(p.text, 20, FontWeight.w800)),
        actions: [
          if (car != null)
            IconButton(
              tooltip: 'Remover',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirmDelete(context, car!);
                if (ok && mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            Container(height: 220, width: double.infinity, color: p.card2, child: preview),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: smallBtn(p, 'Tirar foto', () => pick(ImageSource.camera), icon: Icons.photo_camera, filled: true)),
                const SizedBox(width: 10),
                Expanded(child: smallBtn(p, 'Galeria', () => pick(ImageSource.gallery), icon: Icons.photo_library_outlined)),
              ]),
            ),
          ]),
        ),
        section(p, 'Identificação', Icons.directions_car_outlined, [
          const SizedBox(height: 12),
          BrandSwitch(value: brand, onChanged: (b) => setState(() => brand = b)),
          fieldLabel(p, 'Nome do carrinho'),
          input(p, name, 'Ex.: Cupê Turbo'),
          fieldLabel(p, 'Série'),
          input(p, series, 'Ex.: Mainline 2025'),
          fieldLabel(p, 'Cor'),
          colorDots(p),
        ]),
        section(p, 'Códigos', Icons.qr_code_scanner, [
          fieldLabel(p, 'Código de barras da embalagem'),
          TextField(
            controller: code,
            decoration: field(p, 'Digite ou escaneie o código').copyWith(
              suffixIcon: IconButton(tooltip: 'Escanear código', icon: Icon(Icons.qr_code_scanner, color: p.accent), onPressed: scan),
            ),
          ),
          fieldLabel(p, 'Número do toy (impresso na base do carrinho)'),
          input(p, toy, 'Útil para carrinho solto, sem cartela'),
        ]),
        section(p, 'Status e quantidade', Icons.flag_outlined, [
          fieldLabel(p, 'Marcador'),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final s in statuses) PillChip(s, selected: status == s, onTap: () => setState(() => status = s))]),
          fieldLabel(p, 'Quantidade'),
          Row(children: [
            iconBtn(p, Icons.remove, qty > 1 ? () => setState(() => qty--) : null),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 22), child: Text('$qty', style: ts(p.text, 22, FontWeight.w900))),
            iconBtn(p, Icons.add, () => setState(() => qty++)),
          ]),
          const SizedBox(height: 8),
          switchRow(p, 'Favorito', 'Aparece primeiro na coleção', fav, (v) => setState(() => fav = v)),
          switchRow(p, 'Disponível para troca ou venda', 'Entra na lista da aba Trocas', trade, (v) => setState(() => trade = v)),
        ]),
        section(p, 'Detalhes', Icons.tune, [
          fieldLabel(p, 'Estado'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in conditions) PillChip(s, selected: cond == s, onTap: () => setState(() => cond = cond == s ? '' : s)),
          ]),
          fieldLabel(p, 'Escala'),
          input(p, scale, 'Ex.: 1:64'),
          fieldLabel(p, 'Preço pago'),
          input(p, price, 'Ex.: 9,90', type: const TextInputType.numberWithOptions(decimal: true)),
          fieldLabel(p, 'Onde comprou'),
          input(p, store, 'Loja, feira, troca...'),
          fieldLabel(p, 'Onde guarda'),
          input(p, place, 'Ex.: caixa 2, estante'),
          fieldLabel(p, 'Notas'),
          input(p, notes, 'Defeitos, história, detalhes', lines: 3),
        ]),
      ]),
      bottomNavigationBar: Container(
        color: p.bg,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SafeArea(top: false, child: primary(p, 'Salvar', save, icon: Icons.check)),
      ),
    );
  }
}

// ---------- Leitura de código pela câmera ----------
Future<String?> scanCode(BuildContext context) =>
    Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScanPage()));

class ScanOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height * .42), width: size.width * .8, height: 200);
    final mask = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(mask, Paint()..color = const Color(0xA6000000));
    final corner = Paint()
      ..color = const Color(0xFFE0343F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const l = 30.0;
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        final cx = sx < 0 ? rect.left : rect.right;
        final cy = sy < 0 ? rect.top : rect.bottom;
        canvas.drawLine(Offset(cx, cy), Offset(cx - sx * l, cy), corner);
        canvas.drawLine(Offset(cx, cy), Offset(cx, cy - sy * l), corner);
      }
    }
    canvas.drawLine(
        Offset(rect.left + 16, rect.center.dy),
        Offset(rect.right - 16, rect.center.dy),
        Paint()
          ..color = const Color(0x99E0343F)
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(ScanOverlay old) => false;
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool done = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void onDetect(BarcodeCapture capture) {
    if (done) return;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        done = true;
        Navigator.pop(context, v);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        MobileScanner(controller: controller, onDetect: onDetect),
        IgnorePointer(child: CustomPaint(painter: ScanOverlay())),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              iconBtn(p, Icons.close, () {
                done = true;
                Navigator.pop(context);
              }, tip: 'Fechar'),
              const SizedBox(width: 12),
              Text('COLEÇÃO NA PISTA',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 2.2)),
            ]),
          ),
        ),
        Align(
          alignment: const Alignment(0, .78),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(16)),
            child: Text('Aponte a câmera para o código de barras da embalagem', textAlign: TextAlign.center, style: ts(Colors.white, 14, FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ---------- Já tenho esse? ----------
class CheckPage extends StatefulWidget {
  const CheckPage({super.key, required this.brand, this.autoScan = false});
  final String brand;
  final bool autoScan;

  @override
  State<CheckPage> createState() => _CheckPageState();
}

class _CheckPageState extends State<CheckPage> {
  final code = TextEditingController();
  bool checked = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoScan) WidgetsBinding.instance.addPostFrameCallback((_) => scan());
  }

  Future<void> scan() async {
    final v = await scanCode(context);
    if (v == null || !mounted) return;
    setState(() {
      code.text = v;
      checked = true;
    });
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final found = checked ? garage.byCode(code.text) : null;
    final typed = code.text.trim();
    final isBarcode = RegExp(r'^\d{8,}$').hasMatch(typed); // só números e longo = código de barras
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Já tenho esse?', style: ts(p.text, 20, FontWeight.w800)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        primary(p, 'Escanear com a câmera', scan, icon: Icons.qr_code_scanner),
        const SizedBox(height: 20),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ou digite o código', style: ts(p.text, 15, FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Código de barras ou número do toy (impresso na base do carrinho).', style: ts(p.sub, 12.5)),
            const SizedBox(height: 12),
            TextField(controller: code, onChanged: (_) => setState(() => checked = false), decoration: field(p, 'Código de barras ou número do toy')),
            const SizedBox(height: 12),
            ghost(p, 'Verificar', () => setState(() => checked = typed.isNotEmpty), icon: Icons.search),
          ]),
        ),
        const SizedBox(height: 20),
        if (checked && found != null)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.check_circle, color: p.ok, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(found.qty > 1 ? 'Você já tem este! (×${found.qty})' : 'Você já tem este!', style: ts(p.text, 20, FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 14),
              CarTile(car: found),
              const SizedBox(height: 14),
              ghost(p, 'Comprei outro: somar 1', () {
                found.qty += 1;
                garage.changed();
                Navigator.pop(context);
              }, icon: Icons.add),
            ]),
          ),
        if (checked && found == null)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.info_outline, color: p.accent, size: 28),
                const SizedBox(width: 10),
                Expanded(child: Text('Ainda não tem este', style: ts(p.text, 20, FontWeight.w900))),
              ]),
              const SizedBox(height: 6),
              Text('Nenhum carrinho cadastrado com esse código.', style: ts(p.sub, 13)),
              const SizedBox(height: 14),
              primary(p, 'Cadastrar', () => go(context, CarFormPage(brand: widget.brand, code: isBarcode ? typed : '', toy: isBarcode ? '' : typed)), icon: Icons.add),
            ]),
          ),
      ]),
    );
  }
}

// ---------- Importar planilha ----------
class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final text = TextEditingController();

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (mounted) setState(() => text.text = d?.text ?? '');
  }

  void run() {
    final r = garage.importCsv(text.text);
    if (r == null) {
      snack(context, 'Não entendi a planilha. Use uma linha de títulos com a coluna "nome".');
      return;
    }
    snack(context, '${r[0]} importados, ${r[1]} já existiam');
    if (r[0] > 0) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Importar planilha', style: ts(p.text, 20, FontWeight.w800)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.info_outline, size: 18, color: p.accent),
              const SizedBox(width: 8),
              Text('Como importar', style: ts(p.text, 15, FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            Text(
              'Copie as linhas da sua planilha (Excel, Google Planilhas ou o arquivo exportado pelo app), incluindo a linha de títulos, e cole abaixo. '
              'Só a coluna "nome" é obrigatória. Colunas aceitas: marca, nome, cor, codigo_barras, numero_toy, serie, escala, marcador, quantidade, favorito, troca, preco, onde_comprou, estado, guardado_em, notas.',
              style: ts(p.sub, 13),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        TextField(controller: text, minLines: 8, maxLines: 12, decoration: field(p, 'Cole aqui')),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: ghost(p, 'Colar', paste, icon: Icons.content_paste)),
          const SizedBox(width: 10),
          Expanded(child: primary(p, 'Importar', run, icon: Icons.file_download_outlined)),
        ]),
      ]),
    );
  }
}
