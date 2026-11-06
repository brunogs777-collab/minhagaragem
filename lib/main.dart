// Minha Garagem – versão 2 (Flutter, Android + iOS)
// Pacotes: flutter pub add shared_preferences image_picker path_provider mobile_scanner google_mobile_ads url_launcher share_plus
// Os ajustes de Android (minSdk, AdMob, internet) são feitos pelo workflow build-apk.yml.
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

const bg = Color(0xFF0B0B0F);
const surface = Color(0xFF15151C);
const border = Color(0xFF2A2A36);
const muted = Color(0xFFA3A3B3);
const red = Color(0xFFC1121F);
const blue = Color(0xFF1F4AA8);

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await garage.load();
  MobileAds.instance.updateRequestConfiguration(RequestConfiguration(maxAdContentRating: MaxAdContentRating.g));
  MobileAds.instance.initialize();
  runApp(const GarageApp());
}

class GarageApp extends StatelessWidget {
  const GarageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minha Garagem',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(primary: red, secondary: blue, surface: surface),
        navigationBarTheme: const NavigationBarThemeData(backgroundColor: Color(0xFF0F0F14), indicatorColor: red),
      ),
      home: const Shell(),
    );
  }
}

// ---------- Utilidades de interface ----------
void go(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

void snack(BuildContext context, String t) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

Widget pill(String label, bool selected, VoidCallback onTap) => ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: red,
      backgroundColor: surface,
      side: const BorderSide(color: border, width: 2),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
    );

InputDecoration field(String hint, [IconData? icon]) => InputDecoration(
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: border, width: 2)),
    );

Widget input(TextEditingController c, String hint, {int lines = 1, TextInputType? type}) =>
    TextField(controller: c, minLines: lines, maxLines: lines, keyboardType: type, decoration: field(hint));

Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(t, style: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w700)),
    );

// Silhueta do carrinho (usada quando não há foto).
class CarPainter extends CustomPainter {
  CarPainter(this.color);
  final Color color;

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
      canvas.drawCircle(Offset(x, 34), 8, Paint()..color = bg);
      canvas.drawCircle(
          Offset(x, 34), 8, Paint()..color = const Color(0xFF9A9AAA)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(CarPainter old) => old.color != color;
}

// Mostra a foto do carrinho; sem foto, desenha a silhueta.
class CarImage extends StatelessWidget {
  const CarImage({super.key, required this.car, required this.silhouette});
  final Car car;
  final Size silhouette;

  @override
  Widget build(BuildContext context) {
    final c = carColors[car.color] ?? muted;
    final fallback = Center(child: CustomPaint(size: silhouette, painter: CarPainter(c)));
    final f = garage.photoOf(car);
    if (f == null) return fallback;
    return Image.file(f, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => fallback);
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
        onAdFailedToLoad: (failed, error) {
          failed.dispose();
          ad = null;
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
    final a = ad;
    if (!loaded || a == null) return const SizedBox(height: 66); // reserva o espaço do banner
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: a.size.width.toDouble(),
      height: a.size.height.toDouble(),
      child: AdWidget(ad: a),
    );
  }
}

class CarRow extends StatelessWidget {
  const CarRow({super.key, required this.car, this.trailing});
  final Car car;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = carColors[car.color] ?? muted;
    final sub = car.series.isEmpty ? car.color : '${car.color} · ${car.series}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: surface, border: Border.all(color: border, width: 2), borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        Container(
          width: 84,
          height: 64,
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: Color.lerp(surface, c, .18), borderRadius: BorderRadius.circular(14)),
          child: CarImage(car: car, silhouette: const Size(64, 32)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(car.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(sub, style: const TextStyle(color: muted, fontSize: 13)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
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
  final f = File('${dir.path}/minha-garagem.csv');
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

  final b = StringBuffer('Minha Garagem - $brand\n');
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
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Remover ${car.name}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
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

  @override
  Widget build(BuildContext context) {
    const titles = ['Sua coleção', 'Lista de desejos', 'Trocas e vendas'];
    final pages = <Widget>[CollectionView(brand: brand), WishlistView(brand: brand), TradeView(brand: brand)];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 4, 8),
            child: Row(children: [
              Expanded(child: Text(titles[tab], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
              IconButton.filled(
                tooltip: 'Já tenho esse?',
                style: IconButton.styleFrom(backgroundColor: blue),
                onPressed: () => go(context, CheckPage(brand: brand, autoScan: true)),
                icon: const Icon(Icons.qr_code_scanner),
              ),
              PopupMenuButton<String>(
                tooltip: 'Mais',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(selectedBackgroundColor: red, selectedForegroundColor: Colors.white),
              segments: [for (final b in brands) ButtonSegment(value: b, label: Text(b))],
              selected: {brand},
              onSelectionChanged: (s) => setState(() => brand = s.first),
            ),
          ),
          Expanded(child: pages[tab]),
        ]),
      ),
      floatingActionButton: tab == 2
          ? null
          : FloatingActionButton.extended(
              backgroundColor: red,
              foregroundColor: Colors.white,
              onPressed: () => go(context, CarFormPage(brand: brand, status: tab == 1 ? 'Quero' : 'Tenho')),
              icon: const Icon(Icons.add),
              label: const Text('Novo'),
            ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const AdSlot(),
        NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Coleção'),
            NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Desejos'),
            NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Trocas'),
          ],
        ),
      ]),
    );
  }
}
