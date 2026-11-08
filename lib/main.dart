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
class CollectionView extends StatefulWidget {
  const CollectionView({super.key, required this.brand});
  final String brand;

  @override
  State<CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<CollectionView> {
  String query = '';
  String? filter; // null = Todos

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: garage,
      builder: (context, _) {
        final q = query.toLowerCase();
        final mine = garage.cars
            .where((c) =>
                c.brand == widget.brand &&
                c.status != 'Quero' &&
                passes(c) &&
                (q.isEmpty || '${c.name} ${c.color} ${c.code} ${c.toy} ${c.series} ${c.notes}'.toLowerCase().contains(q)))
            .toList()
            .reversed
            .toList(); // mais novos primeiro
        final list = [...mine.where((c) => c.fav), ...mine.where((c) => !c.fav)]; // favoritos na frente
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: field('Buscar nome, cor, série ou código', Icons.search),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final f in <String?>[null, 'Favoritos', 'Repetidos', 'Treasure Hunt', 'Troca'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: pill(f ?? 'Todos', filter == f, () => setState(() => filter = f)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text('Nenhum carrinho aqui.\nToque em Novo para cadastrar.',
                        textAlign: TextAlign.center, style: TextStyle(color: muted)))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 90),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.9),
                    itemCount: list.length,
                    itemBuilder: (_, i) => CarCard(car: list[i]),
                  ),
          ),
        ]);
      },
    );
  }
}

class CarCard extends StatelessWidget {
  const CarCard({super.key, required this.car});
  final Car car;

  Widget badge(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)),
        child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
      );

  @override
  Widget build(BuildContext context) {
    final c = carColors[car.color] ?? muted;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => go(context, CarFormPage(car: car)),
      onLongPress: () => confirmDelete(context, car),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: surface, border: Border.all(color: border, width: 2), borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: Color.lerp(surface, c, .18),
              child: Stack(children: [
                Positioned.fill(child: CarImage(car: car, silhouette: const Size(124, 62))),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (car.status == 'Treasure Hunt') badge('Treasure Hunt', red),
                    if (car.qty > 1) ...[const SizedBox(height: 4), badge('×${car.qty}', blue)],
                    if (car.trade) ...[const SizedBox(height: 4), badge('Troca', const Color(0xFF3A3A48))],
                  ]),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    tooltip: 'Favorito',
                    onPressed: () {
                      car.fav = !car.fav;
                      garage.changed();
                    },
                    icon: Icon(car.fav ? Icons.favorite : Icons.favorite_border, color: car.fav ? const Color(0xFFFF5A6A) : Colors.white),
                  ),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(car.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              Text(car.color, style: const TextStyle(color: muted, fontSize: 13)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------- Lista de desejos ----------
class WishlistView extends StatelessWidget {
  const WishlistView({super.key, required this.brand});
  final String brand;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: garage,
      builder: (context, _) {
        final list = garage.cars.where((c) => c.brand == brand && c.status == 'Quero').toList();
        if (list.isEmpty) {
          return const Center(
            child: Text('Sua lista está vazia.\nToque em Novo para adicionar o que você procura.',
                textAlign: TextAlign.center, style: TextStyle(color: muted)),
          );
        }
        return Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Links de lojas parceiras podem gerar comissão para o app.', style: TextStyle(color: muted, fontSize: 12)),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => go(context, CarFormPage(car: list[i])),
                child: CarRow(
                  car: list[i],
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Já tenho',
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () {
                        list[i].status = 'Tenho';
                        garage.changed();
                      },
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF3F66C2), width: 2), minimumSize: const Size(0, 44)),
                      onPressed: () => openStore(context, list[i]),
                      child: const Text('Comprar'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

// ---------- Trocas e vendas ----------
class TradeView extends StatelessWidget {
  const TradeView({super.key, required this.brand});
  final String brand;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: garage,
      builder: (context, _) {
        final trade = garage.cars.where((c) => c.brand == brand && c.status != 'Quero' && c.trade).toList();
        final wants = garage.cars.where((c) => c.brand == brand && c.status == 'Quero').toList();
        return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 90), children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52)),
            onPressed: () {
              if (trade.isEmpty && wants.isEmpty) {
                snack(context, 'Marque carrinhos para troca ou adicione itens à lista de desejos');
                return;
              }
              SharePlus.instance.share(ShareParams(text: tradeText(brand)));
            },
            icon: const Icon(Icons.share),
            label: const Text('Compartilhar (WhatsApp e outros)', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          label('Para troca ou venda (${trade.length})'),
          if (trade.isEmpty)
            const Text('Abra um carrinho e ligue "Disponível para troca ou venda".', style: TextStyle(color: muted))
          else
            for (final c in trade)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => go(context, CarFormPage(car: c)),
                  child: CarRow(car: c, trailing: c.qty > 1 ? Text('×${c.qty}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)) : null),
                ),
              ),
          label('Procuro (${wants.length})'),
          if (wants.isEmpty)
            const Text('Sua lista de desejos está vazia.', style: TextStyle(color: muted))
          else
            for (final c in wants)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: CarRow(car: c)),
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
    final ctl = TextEditingController(text: '$current');
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quantos carrinhos tem a série?'),
        content: TextField(controller: ctl, keyboardType: TextInputType.number, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctl.text.trim())), child: const Text('Salvar')),
        ],
      ),
    );
    if (n != null && n > 0) garage.setTotal(key, n);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Séries · $brand')),
      body: ListenableBuilder(
        listenable: garage,
        builder: (context, _) {
          final names = <String>{};
          for (final c in garage.cars) {
            if (c.brand == brand && c.series.trim().isNotEmpty) names.add(c.series.trim());
          }
          if (names.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Preencha o campo "Série" nos carrinhos para acompanhar o progresso de cada série.',
                    textAlign: TextAlign.center, style: TextStyle(color: muted)),
              ),
            );
          }
          final list = names.toList()..sort();
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final s = list[i];
              final inSeries = garage.cars.where((c) => c.brand == brand && c.series.trim() == s);
              final owned = inSeries.where((c) => c.status != 'Quero').length;
              final wanted = inSeries.where((c) => c.status == 'Quero').length;
              final key = '$brand|$s';
              final total = garage.totals[key] ?? (owned + wanted);
              final p = total == 0 ? 0.0 : (owned / total).clamp(0.0, 1.0).toDouble();
              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => editTotal(context, key, total),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: surface, border: Border.all(color: border, width: 2), borderRadius: BorderRadius.circular(22)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(s, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                      Text('$owned de $total', style: const TextStyle(color: muted, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: p, minHeight: 8, color: red, backgroundColor: border, borderRadius: BorderRadius.circular(4)),
                    const SizedBox(height: 8),
                    const Text('Toque para informar o total da série', style: TextStyle(color: muted, fontSize: 12)),
                  ]),
                ),
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
    final p = picked;
    final photo = p == null ? null : await garage.savePhoto(p);
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

  @override
  Widget build(BuildContext context) {
    final existing = car == null ? null : garage.photoOf(car!);
    final Widget preview = picked != null
        ? Image.file(File(picked!.path), fit: BoxFit.cover, width: double.infinity)
        : existing != null
            ? Image.file(existing, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => const Icon(Icons.photo_camera_outlined, size: 48, color: muted))
            : const Center(child: Icon(Icons.photo_camera_outlined, size: 48, color: muted));
    return Scaffold(
      appBar: AppBar(
        title: Text(car == null ? 'Novo carrinho' : 'Editar carrinho'),
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
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        const SizedBox(height: 8),
        Container(
          height: 200,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: surface, border: Border.all(color: border, width: 2), borderRadius: BorderRadius.circular(24)),
          child: preview,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
              onPressed: () => pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Tirar foto'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Galeria'),
            ),
          ),
        ]),
        label('Coleção'),
        Wrap(spacing: 8, children: [for (final b in brands) pill(b, brand == b, () => setState(() => brand = b))]),
        label('Nome do carrinho'),
        input(name, 'Ex.: Cupê Turbo'),
        label('Código de barras da embalagem'),
        TextField(
          controller: code,
          decoration: field('Digite ou escaneie o código').copyWith(
            suffixIcon: IconButton(tooltip: 'Escanear código', icon: const Icon(Icons.qr_code_scanner), onPressed: scan),
          ),
        ),
        label('Número do toy (impresso na base do carrinho)'),
        input(toy, 'Útil para carrinho solto, sem cartela'),
        label('Série'),
        input(series, 'Ex.: Mainline 2025'),
        label('Cor'),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final k in carColors.keys) pill(k, color == k, () => setState(() => color = k))]),
        label('Marcador'),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final s in statuses) pill(s, status == s, () => setState(() => status = s))]),
        label('Quantidade'),
        Row(children: [
          IconButton.outlined(onPressed: qty > 1 ? () => setState(() => qty--) : null, icon: const Icon(Icons.remove)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('$qty', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          IconButton.outlined(onPressed: () => setState(() => qty++), icon: const Icon(Icons.add)),
        ]),
        const SizedBox(height: 8),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Favorito'), value: fav, onChanged: (v) => setState(() => fav = v)),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Disponível para troca ou venda'),
            value: trade,
            onChanged: (v) => setState(() => trade = v)),
        label('Estado'),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final s in conditions) pill(s, cond == s, () => setState(() => cond = cond == s ? '' : s))]),
        label('Escala'),
        input(scale, 'Ex.: 1:64'),
        label('Preço pago'),
        input(price, 'Ex.: 9,90', type: const TextInputType.numberWithOptions(decimal: true)),
        label('Onde comprou'),
        input(store, 'Loja, feira, troca...'),
        label('Onde guarda'),
        input(place, 'Ex.: caixa 2, estante'),
        label('Notas'),
        input(notes, 'Defeitos, história, detalhes', lines: 3),
        const SizedBox(height: 28),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56)),
          onPressed: save,
          child: const Text('Salvar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

// ---------- Leitura de código pela câmera ----------
Future<String?> scanCode(BuildContext context) =>
    Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScanPage()));

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
    return Scaffold(
      body: Stack(children: [
        MobileScanner(controller: controller, onDetect: onDetect),
        Center(
          child: Container(
            width: 260,
            height: 170,
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFF3F66C2), width: 4), borderRadius: BorderRadius.circular(20)),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              IconButton.filled(
                tooltip: 'Fechar',
                style: IconButton.styleFrom(backgroundColor: surface),
                onPressed: () {
                  done = true;
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
                child: const Text('Aponte para o código de barras', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ]),
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
    final found = checked ? garage.byCode(code.text) : null;
    final typed = code.text.trim();
    final isBarcode = RegExp(r'^\d{8,}$').hasMatch(typed); // só números e longo = código de barras
    return Scaffold(
      appBar: AppBar(title: const Text('Já tenho esse?')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56)),
          onPressed: scan,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear com a câmera', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 18),
        const Text('Ou digite o código de barras ou o número do toy (impresso na base do carrinho):', style: TextStyle(color: muted)),
        const SizedBox(height: 14),
        TextField(controller: code, onChanged: (_) => setState(() => checked = false), decoration: field('Código de barras ou número do toy')),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52)),
          onPressed: () => setState(() => checked = typed.isNotEmpty),
          child: const Text('Verificar'),
        ),
        const SizedBox(height: 24),
        if (checked && found != null) ...[
          Text(found.qty > 1 ? 'Você já tem este! (×${found.qty})' : 'Você já tem este!', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          CarRow(car: found),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () {
              found.qty += 1;
              garage.changed();
              Navigator.pop(context);
            },
            child: const Text('Comprei outro: somar 1'),
          ),
        ],
        if (checked && found == null) ...[
          const Text('Ainda não tem este', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52)),
            onPressed: () => go(
              context,
              CarFormPage(brand: widget.brand, code: isBarcode ? typed : '', toy: isBarcode ? '' : typed),
            ),
            child: const Text('Cadastrar'),
          ),
        ],
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
    return Scaffold(
      appBar: AppBar(title: const Text('Importar planilha')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text(
          'Copie as linhas da sua planilha (Excel, Google Planilhas ou o arquivo exportado pelo app), incluindo a linha de títulos, e cole abaixo. '
          'Só a coluna "nome" é obrigatória. Colunas aceitas: marca, nome, cor, codigo_barras, numero_toy, serie, escala, marcador, quantidade, favorito, troca, preco, onde_comprou, estado, guardado_em, notas.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: text,
          minLines: 8,
          maxLines: 12,
          decoration: InputDecoration(
            hintText: 'Cole aqui',
            filled: true,
            fillColor: surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: border, width: 2)),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: paste,
              icon: const Icon(Icons.content_paste),
              label: const Text('Colar'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52)),
              onPressed: run,
              child: const Text('Importar', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ]),
    );
  }
}
