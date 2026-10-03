import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const WebMaterialesApp());

class WebMaterialesApp extends StatelessWidget {
  const WebMaterialesApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Consulta de materiales SAP',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
          scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        ),
        home: const MaterialesPage(),
      );
}

class MaterialesPage extends StatefulWidget {
  const MaterialesPage({super.key});
  @override
  State<MaterialesPage> createState() => _MaterialesPageState();
}

class _MaterialesPageState extends State<MaterialesPage> {
  static const baseUrl = 'https://gsesrwdcc.santaelena.com.pe:44300/zmat_consulta/material';
  static const sapClient = '200';

  final matnr = TextEditingController();
  final desde = TextEditingController();
  final hasta = TextEditingController();
  final pageSizeCtl = TextEditingController(text: '5');
  final userCtl = TextEditingController();
  final passCtl = TextEditingController();
  final passFocus = FocusNode();

  String? username, password, error;
  bool loading = false, obscure = true;
  Map<String, dynamic>? individual;
  List<Map<String, dynamic>> range = [];
  int total = 0, offset = 0, pageSize = 5;

  bool get logged => username?.isNotEmpty == true && password?.isNotEmpty == true;
  Map<String, String> get headers => {
        'Accept': 'application/json',
        'Authorization': 'Basic ${base64Encode(utf8.encode('$username:$password'))}',
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _login());
  }

  @override
  void dispose() {
    for (final c in [matnr, desde, hasta, pageSizeCtl, userCtl, passCtl]) { c.dispose(); }
    passFocus.dispose();
    super.dispose();
  }

  void _login() {
    userCtl.clear();
    passCtl.clear();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dc) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
            title: const Row(children: [Icon(Icons.lock_outline, color: Color(0xFF1565C0)), SizedBox(width: 10), Text('Acceso a SAP')]),
            content: SizedBox(
              width: 420,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Align(alignment: Alignment.centerLeft, child: Text('Ingresa tus credenciales SAP para consultar materiales.')),
                const SizedBox(height: 18),
                TextField(controller: userCtl, autofocus: true, decoration: const InputDecoration(labelText: 'Usuario SAP', prefixIcon: Icon(Icons.person_outline)), onSubmitted: (_) => passFocus.requestFocus()),
                const SizedBox(height: 14),
                TextField(
                  controller: passCtl,
                  focusNode: passFocus,
                  obscureText: obscure,
                  decoration: InputDecoration(labelText: 'ContraseÃ±a SAP', prefixIcon: const Icon(Icons.key_outlined), suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setDialogState(() => obscure = !obscure))),
                  onSubmitted: (_) => _doLogin(dc),
                ),
                const SizedBox(height: 14),
                const Text('La contraseÃ±a no estÃ¡ escrita en el cÃ³digo. Se mantiene solamente en memoria mientras esta sesiÃ³n estÃ¡ abierta.', style: TextStyle(fontSize: 12, color: Color(0xFF607D8B))),
              ]),
            ),
            actions: [FilledButton.icon(onPressed: () => _doLogin(dc), icon: const Icon(Icons.login), label: const Text('Ingresar a SAP'))],
          )),
    );
  }

  void _doLogin(BuildContext dc) {
    final u = userCtl.text.trim(), p = passCtl.text;
    if (u.isEmpty || p.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa usuario y contraseÃ±a SAP.')));
      return;
    }
    setState(() { username = u; password = p; error = null; individual = null; range = []; });
    Navigator.of(dc).pop();
  }

  void _logout() {
    setState(() { username = null; password = null; error = null; individual = null; range = []; total = 0; offset = 0; });
    _login();
  }

  String _pad(String v) => v.padLeft(18, '0');
  int _int(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  Future<void> _consultIndividual() async {
    if (!logged) return _login();
    final value = matnr.text.trim();
    if (value.isEmpty) return setState(() { error = 'Ingresa un cÃ³digo de material.'; individual = null; });
    final uri = Uri.parse('$baseUrl?sap-client=$sapClient&MATNR=${Uri.encodeQueryComponent(_pad(value))}');
    setState(() { loading = true; error = null; individual = null; });
    try {
      final r = await http.get(uri, headers: headers);
      if (!mounted) return;
      if (r.statusCode == 200) {
        setState(() { individual = jsonDecode(r.body) as Map<String, dynamic>; loading = false; });
      } else if (r.statusCode == 401) {
        setState(() { loading = false; error = 'SAP respondiÃ³ HTTP 401. Verifica usuario, contraseÃ±a y permisos.'; });
      } else {
        setState(() { loading = false; error = 'SAP respondiÃ³ HTTP ${r.statusCode}.'; });
      }
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'No fue posible comunicarse con SAP. Verifica la conexiÃ³n y el servicio.'; });
    }
  }

  Future<void> _consultRange({bool reset = true}) async {
    if (!logged) return _login();
    final d = desde.text.trim(), h = hasta.text.trim(), ps = int.tryParse(pageSizeCtl.text.trim());
    if (d.isEmpty || h.isEmpty) return setState(() => error = 'Ingresa material desde y material hasta.');
    if (ps == null || ps <= 0) return setState(() => error = 'El tamaÃ±o de pÃ¡gina debe ser mayor que cero.');
    if (reset) offset = 0;
    pageSize = ps;
    final uri = Uri.parse('$baseUrl?sap-client=$sapClient&MATNR_DESDE=${Uri.encodeQueryComponent(_pad(d))}&MATNR_HASTA=${Uri.encodeQueryComponent(_pad(h))}&PAGE_SIZE=$pageSize&OFFSET=$offset');
    setState(() { loading = true; error = null; });
    try {
      final r = await http.get(uri, headers: headers);
      if (!mounted) return;
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final raw = data['MATERIALS'] ?? data['MATERIALES'] ?? data['materials'] ?? [];
        final list = raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
        setState(() {
          range = list;
          total = _int(data['TOTAL'] ?? data['total']);
          pageSize = _int(data['PAGE_SIZE'] ?? data['page_size']) > 0 ? _int(data['PAGE_SIZE'] ?? data['page_size']) : pageSize;
          offset = _int(data['OFFSET'] ?? data['offset']);
          loading = false;
          final msg = data['MESSAGE']?.toString() ?? '';
          if (msg.isNotEmpty) error = msg;
        });
      } else if (r.statusCode == 401) {
        setState(() { loading = false; error = 'SAP respondiÃ³ HTTP 401. Verifica usuario, contraseÃ±a y permisos.'; });
      } else {
        setState(() { loading = false; error = 'SAP respondiÃ³ HTTP ${r.statusCode}.'; });
      }
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'No fue posible comunicarse con SAP. Verifica la conexiÃ³n y el servicio.'; });
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            title: const Row(children: [Icon(Icons.inventory_2_outlined), SizedBox(width: 10), Text('Consulta de materiales SAP', style: TextStyle(fontWeight: FontWeight.w700))]),
            actions: [if (logged) Padding(padding: const EdgeInsets.only(right: 12), child: Row(children: [Text(username!), const SizedBox(width: 8), IconButton(tooltip: 'Cerrar sesiÃ³n', onPressed: _logout, icon: const Icon(Icons.logout))]))],
          ),
          body: Column(children: [
            Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(20, 20, 20, 16), color: const Color(0xFF1565C0), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: const Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ConexiÃ³n al servicio REST', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)), SizedBox(height: 4), Text('ZMAT_CONSULTA Â· Cliente SAP 200', style: TextStyle(color: Colors.white70))])), Icon(Icons.verified_user_outlined, color: Colors.white, size: 32)])))),
            const Material(color: Colors.white, child: TabBar(tabs: [Tab(icon: Icon(Icons.search), text: 'Consulta individual'), Tab(icon: Icon(Icons.table_rows_outlined), text: 'Consulta por rangos')])),
            Expanded(child: TabBarView(children: [_individualView(), _rangeView()])),
          ]),
        ),
      );

  Widget _card(Widget child) => SingleChildScrollView(padding: const EdgeInsets.all(24), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)), child: Padding(padding: const EdgeInsets.all(28), child: child)))));

  Widget _individualView() => _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [CircleAvatar(radius: 27, backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.qr_code_scanner, color: Color(0xFF1565C0))), SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Buscar un material', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, color: Color(0xFF1D3557))), SizedBox(height: 4), Text('Ingresa el cÃ³digo exacto que deseas consultar.', style: TextStyle(color: Color(0xFF607D8B)))])]),
        const SizedBox(height: 30),
        TextField(controller: matnr, enabled: !loading, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'CÃ³digo de material (MATNR)', prefixIcon: Icon(Icons.inventory_2_outlined)), onSubmitted: (_) => _consultIndividual()),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: loading ? null : _consultIndividual, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search), label: Text(loading ? 'Consultando...' : 'Consultar material')),
        const SizedBox(height: 24),
        if (error != null) _error(error!),
        if (individual != null) _individualResult(individual!),
      ]));

  Widget _individualResult(Map<String, dynamic> d) {
    final msg = d['MESSAGE']?.toString() ?? '';
    if (msg.isNotEmpty) return _box(const Color(0xFFFFF8E1), const Color(0xFFFFE082), Icons.info_outline, msg);
    return Container(width: double.infinity, padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFA5D6A7))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32)), SizedBox(width: 10), Text('Material encontrado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))]), const SizedBox(height: 18), _line('Material', d['MATNR']), _line('Fecha de creaciÃ³n', d['ERSDA']), _line('Creado por', d['ERNAM'])]));
  }

  Widget _line(String l, dynamic v) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [SizedBox(width: 170, child: Text('$l:', style: const TextStyle(fontWeight: FontWeight.w600))), Expanded(child: Text(v?.toString() ?? ''))]));

  Widget _rangeView() => _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Consulta por rangos', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, color: Color(0xFF1D3557))),
        const SizedBox(height: 6), const Text('Consulta materiales por un intervalo y navega por pÃ¡ginas.', style: TextStyle(color: Color(0xFF607D8B))), const SizedBox(height: 24),
        Wrap(spacing: 14, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [SizedBox(width: 250, child: TextField(controller: desde, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Material desde'))), SizedBox(width: 250, child: TextField(controller: hasta, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Material hasta'))), SizedBox(width: 130, child: TextField(controller: pageSizeCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Por pÃ¡gina'))), FilledButton.icon(onPressed: loading ? null : () => _consultRange(), icon: const Icon(Icons.search), label: const Text('Consultar rango'))]),
        const SizedBox(height: 24), if (error != null) _error(error!), if (range.isNotEmpty) _rangeTable(),
      ]));

  Widget _rangeTable() {
    final prev = offset > 0, next = offset + pageSize < total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Resultados: $total registros Â· PÃ¡gina ${total == 0 ? 0 : (offset ~/ pageSize) + 1}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF455A64))), const SizedBox(height: 12), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(const Color(0xFFE3F2FD)), columns: const [DataColumn(label: Text('MATNR')), DataColumn(label: Text('ERSDA')), DataColumn(label: Text('ERNAM'))], rows: range.map((m) => DataRow(cells: [DataCell(Text(m['MATNR']?.toString() ?? '')), DataCell(Text(m['ERSDA']?.toString() ?? '')), DataCell(Text(m['ERNAM']?.toString() ?? ''))])).toList())), const SizedBox(height: 16), Row(children: [OutlinedButton.icon(onPressed: prev && !loading ? () { setState(() => offset = (offset - pageSize).clamp(0, offset)); _consultRange(reset: false); } : null, icon: const Icon(Icons.chevron_left), label: const Text('Anterior')), const SizedBox(width: 10), OutlinedButton.icon(onPressed: next && !loading ? () { setState(() => offset += pageSize); _consultRange(reset: false); } : null, icon: const Icon(Icons.chevron_right), label: const Text('Siguiente')), const Spacer(), Text('Mostrando ${offset + 1}-${(offset + range.length).clamp(0, total)} de $total')])]);
  }

  Widget _error(String msg) => _box(const Color(0xFFFFEBEE), const Color(0xFFFFCDD2), Icons.error_outline, msg, textColor: const Color(0xFFC62828));
  Widget _box(Color bg, Color border, IconData icon, String msg, {Color? textColor}) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: textColor ?? const Color(0xFF8D6E00)), const SizedBox(width: 10), Expanded(child: Text(msg, style: TextStyle(color: textColor)))]));
}




