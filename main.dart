// Minha Garagem – versão 1 (Flutter, iOS + Android)
// Uso: flutter create minha_garagem && cd minha_garagem
//      flutter pub add shared_preferences image_picker path_provider mobile_scanner google_mobile_ads url_launcher
//      iOS: em ios/Runner/Info.plist adicione NSCameraUsageDescription e NSPhotoLibraryUsageDescription
//      (texto explicando que o app usa a câmera para fotos e para ler códigos)
// Android: minSdk 24 em android/app/build.gradle + App ID do AdMob (meta-data) no AndroidManifest.xml.
// iOS: chave GADApplicationIdentifier (App ID do AdMob) no Info.plist.
//      troque lib/main.dart por este arquivo e rode: flutter run
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const bg = Color(0xFF0B0B0F);
const surface = Color(0xFF15151C);
const border = Color(0xFF2A2A36);
const muted = Color(0xFFA3A3B3);
const red = Color(0xFFC1121F);
const blue = Color(0xFF1F4AA8);

const brands = ['Hot Wheels', 'Matchbox'];
const statuses = ['Tenho', 'Quero', 'Repetido', 'Treasure Hunt'];
const carColors = <String, Color>{
  'Vermelho': Color(0xFFE5384A),
  'Azul': Color(0xFF3D7BEF),
  'Amarelo': Color(0xFFF5B91A),
  'Verde': Color(0xFF34B56A),
  'Prata': Color(0xFFC9CCD6),
};

// ---------- Dados e armazenamento local ----------
class Car {
  Car({
    required this.id,
    required this.name,
    required this.code,
    required this.color,
    required this.brand,
    required this.status,
    this.photo = '',
  });

  final String id, name, code, color, brand;
  String status;
  String photo;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'color': color,
        'brand': brand,
        'status': status,
        'photo': photo,
      };

  factory Car.fromJson(Map<String, dynamic> j) => Car(
        id: j['id'],
        name: j['name'],
        code: j['code'],
        color: j['color'],
        brand: j['brand'],
        status: j['status'],
        photo: j['photo'] ?? '',
      );
}

class Garage extends ChangeNotifier {
  final List<Car> cars = [];
  SharedPreferences? _prefs;
  String docsPath = '';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    docsPath = (await getApplicationDocumentsDirectory()).path;

    try {
      final raw = _prefs!.getString('cars');
      if (raw == null) return;

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            cars.add(Car.fromJson(item));
          }
        }
      }
    } catch (_) {
      cars.clear();
    }
  }

  void _save() {
    _prefs?.setString('cars', jsonEncode(cars.map((c) => c.toJson()).toList()));
    notifyListeners();
  }

  void add(Car c) {
    cars.add(c);
    _save();
  }

  void setStatus(Car c, String s) {
    c.status = s;
    _save();
  }

  void remove(Car c) {
    final f = photoOf(c);
    if (f != null && f.existsSync()) f.deleteSync();
    cars.remove(c);
    _save();
  }

  File? photoOf(Car c) => c.photo.isEmpty ? null : File('$docsPath/${c.photo}');

  // Copia a foto para a pasta do app (a original do seletor pode ser apagada pelo sistema).
  Future<String> savePhoto(XFile f) async {
    final name = 'car_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(f.path).copy('$docsPath/$name');
    return name;
  }

  // Usado pelo "Já tenho esse?": só considera carrinhos que a pessoa já possui.
  Car? byCode(String code) {
    final k = code.trim().toLowerCase();
    if (k.isEmpty) return null;
    for (final c in cars) {
      if (c.code.trim().toLowerCase() == k && c.status != 'Quero') return c;
    }
    return null;
  }
}

final garage = Garage();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await garage.load();
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
  );
  await MobileAds.instance.initialize();
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
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF0F0F14),
          indicatorColor: red,
        ),
      ),
      home: const Shell(),
    );
  }
}

// ---------- Utilidades de interface ----------
void go(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: border, width: 2),
      ),
    );

Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(t, style: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w700)),
    );

// Silhueta do carrinho (a foto real entra na próxima etapa).
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
        Offset(x, 34),
        8,
        Paint()
          ..color = const Color(0xFF9A9AAA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
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
    return Image.file(
      f,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => fallback,
    );
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
    if (!loaded || a == null) return const SizedBox(height: 66);
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border, width: 2),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(children: [
        Container(
          width: 84,
          height: 64,
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Color.lerp(surface, c, .18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: CarImage(car: car, silhouette: const Size(64, 32)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(car.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(car.color, style: const TextStyle(color: muted, fontSize: 13)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
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
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(children: [
              Expanded(
                child: Text(
                  tab == 0 ? 'Sua coleção' : 'Lista de desejos',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton.filled(
                tooltip: 'Já tenho esse?',
                style: IconButton.styleFrom(backgroundColor: blue),
                onPressed: () => go(context, CheckPage(brand: brand, autoScan: true)),
                icon: const Icon(Icons.qr_code_scanner),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: red,
                selectedForegroundColor: Colors.white,
              ),
              segments: [for (final b in brands) ButtonSegment(value: b, label: Text(b))],
              selected: {brand},
              onSelectionChanged: (s) => setState(() => brand = s.first),
            ),
          ),
          Expanded(child: tab == 0 ? CollectionView(brand: brand) : WishlistView(brand: brand)),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: red,
        foregroundColor: Colors.white,
        onPressed: () => go(context, AddCarPage(brand: brand)),
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
          ],
        ),
      ]),
    );
  }
}

// ---------- Coleção ----------
class CollectionView extends StatefulWidget {
  const CollectionView({super.key, required this.brand});
  final String brand;

  @override
  State<CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<CollectionView> {
  String query = '';
  String? filter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: garage,
      builder: (context, _) {
        final q = query.toLowerCase();
        final list = garage.cars
            .where((c) =>
                c.brand == widget.brand &&
                c.status != 'Quero' &&
                (filter == null || c.status == filter) &&
                (q.isEmpty || '${c.name} ${c.color} ${c.code}'.toLowerCase().contains(q)))
            .toList();

        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: field('Buscar nome, cor ou código', Icons.search),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final f in <String?>[null, 'Tenho', 'Repetido', 'Treasure Hunt'])
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
                    child: Text(
                      'Nenhum carrinho ainda.\nToque em Novo para cadastrar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 90),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.9,
                    ),
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

  @override
  Widget build(BuildContext context) {
    final c = carColors[car.color] ?? muted;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onLongPress: () => confirmDelete(context, car),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border, width: 2),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: Color.lerp(surface, c, .18),
              child: Stack(children: [
                Positioned.fill(child: CarImage(car: car, silhouette: const Size(124, 62))),
                if (car.status != 'Tenho')
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: car.status == 'Repetido' ? blue : red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        car.status,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                car.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              Text(car.color, style: const TextStyle(color: muted, fontSize: 13)),
            ]),
          ),
        ]),
      ),
    );
  }
}

Future<void> confirmDelete(BuildContext context, Car car) async {
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
}

// ---------- Afiliados (botão Comprar) ----------
// Troque SEU_CODIGO pelo seu código de afiliado ao entrar num programa (o formato abaixo é o da Amazon).
// Sem código, o link funciona como uma busca comum, mas não gera comissão.
const affiliateSearch = 'https://www.amazon.com.br/s?k={q}&tag=SEU_CODIGO';

Future<void> openStore(BuildContext context, Car c) async {
  final url = affiliateSearch.replaceAll('{q}', Uri.encodeQueryComponent('${c.brand} ${c.name}'));
  final uri = Uri.parse(url);

  try {
    if (await canLaunchUrl(uri)) {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir a loja')),
        );
      }
      return;
    }
  } catch (_) {}

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir a loja')),
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
            child: Text(
              'Sua lista está vazia.\nCadastre um carrinho com o marcador Quero.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
          );
        }

        return Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Links de lojas parceiras podem gerar comissão para o app.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => CarRow(
                car: list[i],
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Já tenho',
                    icon: const Icon(Icons.check_circle_outline),
                    onPressed: () => garage.setStatus(list[i], 'Tenho'),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF3F66C2), width: 2),
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => openStore(context, list[i]),
                    child: const Text('Comprar'),
                  ),
                ]),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

// ---------- Novo carrinho ----------
class AddCarPage extends StatefulWidget {
  const AddCarPage({super.key, required this.brand, this.code = ''});
  final String brand, code;

  @override
  State<AddCarPage> createState() => _AddCarPageState();
}

class _AddCarPageState extends State<AddCarPage> {
  late final code = TextEditingController(text: widget.code);
  final name = TextEditingController();
  late String brand = widget.brand;
  XFile? picked;
  String color = carColors.keys.first;
  String status = statuses.first;

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> pick(ImageSource source) async {
    try {
      final f = await ImagePicker().pickImage(source: source, maxWidth: 1280, imageQuality: 85);
      if (f != null && mounted) setState(() => picked = f);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir a câmera ou a galeria')),
        );
      }
    }
  }

  Future<void> save() async {
    final codeText = code.text.trim();
    final nameText = name.text.trim();

    if (nameText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dê um nome ao carrinho')),
      );
      return;
    }

    final existing = garage.byCode(codeText);
    if (codeText.isNotEmpty && existing != null && existing.status != 'Quero') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este código já existe na sua coleção')),
      );
      return;
    }

    final p = picked;
    final photo = p == null ? '' : await garage.savePhoto(p);
    garage.add(Car(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: nameText,
      code: codeText,
      color: color,
      brand: brand,
      status: status,
      photo: photo,
    ));

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo carrinho')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        const SizedBox(height: 8),
        Container(
          height: 200,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(color: border, width: 2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: picked == null
              ? const Center(child: Icon(Icons.photo_camera_outlined, size: 48, color: muted))
              : Image.file(File(picked!.path), fit: BoxFit.cover, width: double.infinity),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: red,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
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
        Wrap(
          spacing: 8,
          children: [for (final b in brands) pill(b, brand == b, () => setState(() => brand = b))],
        ),
        label('Código da embalagem'),
        TextField(
          controller: code,
          decoration: field('Digite ou escaneie o código').copyWith(
            suffixIcon: IconButton(
              tooltip: 'Escanear código',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () async {
                final v = await scanCode(context);
                if (v != null && mounted) setState(() => code.text = v);
              },
            ),
          ),
        ),
        label('Nome do carrinho'),
        TextField(controller: name, decoration: field('Ex.: Cupê Turbo')),
        label('Cor'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final k in carColors.keys) pill(k, color == k, () => setState(() => color = k))],
        ),
        label('Marcador'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final s in statuses) pill(s, status == s, () => setState(() => status = s))],
        ),
        const SizedBox(height: 28),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: red,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: save,
          child: const Text('Salvar na coleção', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
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
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF3F66C2), width: 4),
              borderRadius: BorderRadius.circular(20),
            ),
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
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Aponte para o código de barras',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
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
  final bool autoScan;
  final String brand;

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

    return Scaffold(
      appBar: AppBar(title: const Text('Já tenho esse?')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: red,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: scan,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear com a câmera', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 18),
        const Text('Ou digite o código da embalagem:', style: TextStyle(color: muted)),
        const SizedBox(height: 14),
        TextField(
          controller: code,
          onChanged: (_) => setState(() => checked = false),
          decoration: field('Código da embalagem'),
        ),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: blue,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: () => setState(() => checked = code.text.trim().isNotEmpty),
          child: const Text('Verificar'),
        ),
        const SizedBox(height: 24),
        if (checked && found != null) ...[
          const Text('Você já tem este!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          CarRow(car: found),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () {
              garage.setStatus(found, 'Repetido');
              Navigator.pop(context);
            },
            child: const Text('Marcar como repetido'),
          ),
        ],
        if (checked && found == null) ...[
          const Text('Ainda não tem este', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: red,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => go(context, AddCarPage(brand: widget.brand, code: code.text.trim())),
            child: const Text('Cadastrar'),
          ),
        ],
      ]),
    );
  }
}
