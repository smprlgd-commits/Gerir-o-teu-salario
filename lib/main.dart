import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gerir o Teu Salário',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C5CE7)),
      ),
      home: const HomePage(),
    );
  }
}

class Despesa {
  String nome;
  double valor;
  String categoria;
  Despesa({required this.nome, required this.valor, required this.categoria});
  Map<String, dynamic> toJson() => {'nome': nome, 'valor': valor, 'categoria': categoria};
  factory Despesa.fromJson(Map<String, dynamic> j) => Despesa(nome: j['nome'], valor: (j['valor'] as num).toDouble(), categoria: j['categoria']);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double salario = 0;
  List<Despesa> despesas = [];
  final salarioCtrl = TextEditingController();
  final nomeCtrl = TextEditingController();
  final valorCtrl = TextEditingController();
  String categoriaSel = 'Alimentação';
  final categorias = ['Alimentação', 'Transporte', 'Renda', 'Lazer', 'Saúde', 'Outros'];
  final cores = {
    'Alimentação': Colors.orange,
    'Transporte': Colors.blue,
    'Renda': Colors.red,
    'Lazer': Colors.purple,
    'Saúde': Colors.green,
    'Outros': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      salario = prefs.getDouble('salario') ?? 0;
      salarioCtrl.text = salario == 0 ? '' : salario.toStringAsFixed(0);
      final lista = prefs.getStringList('despesas') ?? [];
      despesas = lista.map((e) => Despesa.fromJson(jsonDecode(e))).toList();
    });
  }

  Future<void> _salvar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('salario', salario);
    await prefs.setStringList('despesas', despesas.map((e) => jsonEncode(e.toJson())).toList());
  }

  double get totalGasto => despesas.fold(0, (s, e) => s + e.valor);
  double get restante => salario - totalGasto;
  double get percent => salario == 0 ? 0 : (totalGasto / salario).clamp(0, 1);

  void _adicionarDespesa() {
    if (nomeCtrl.text.isEmpty || valorCtrl.text.isEmpty) return;
    setState(() {
      despesas.add(Despesa(nome: nomeCtrl.text, valor: double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0, categoria: categoriaSel));
      nomeCtrl.clear();
      valorCtrl.clear();
    });
    _salvar();
    Navigator.pop(context);
  }

  void _mostrarAdd() {
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Nova Despesa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: 'Nome ex: Pão, Táxi', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: valorCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor (Kz)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: categoriaSel, items: categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => categoriaSel = v!), decoration: const InputDecoration(border: OutlineInputBorder())),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _adicionarDespesa, child: const Text('Adicionar'))),
        const SizedBox(height: 20),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    Map<String, double> porCat = {};
    for (var d in despesas) { porCat[d.categoria] = (porCat[d.categoria] ?? 0) + d.valor; }

    return Scaffold(
      appBar: AppBar(title: const Text('Gerir o Teu Salário'), centerTitle: true),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          const Text('Teu Salário Mensal (Kz)'),
          const SizedBox(height: 8),
          TextField(controller: salarioCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), prefixText: 'Kz '), onChanged: (v) {
            setState(() => salario = double.tryParse(v.replaceAll(',', '.')) ?? 0);
            _salvar();
          }),
        ]))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _cardInfo('Gastaste', '${totalGasto.toStringAsFixed(0)} Kz', Colors.red)),
          const SizedBox(width: 10),
          Expanded(child: _cardInfo('Restante', '${restante.toStringAsFixed(0)} Kz', restante < 0 ? Colors.red : Colors.green)),
        ]),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: percent, minHeight: 10, backgroundColor: Colors.grey[200]),
        Text('${(percent * 100).toStringAsFixed(0)}% do salário usado'),
        const SizedBox(height: 16),
        const Text('Por Categoria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (porCat.isNotEmpty) SizedBox(height: 180, child: PieChart(PieChartData(sections: porCat.entries.map((e) => PieChartSectionData(value: e.value, title: '${e.key}\n${e.value.toStringAsFixed(0)}', color: cores[e.key], titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))).toList()))),
        if (porCat.isEmpty) const Text('Ainda não tens despesas. Clica em + para adicionar.'),
        const SizedBox(height: 16),
        const Text('Todas as Despesas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ...despesas.map((d) => Card(child: ListTile(leading: CircleAvatar(backgroundColor: cores[d.categoria], child: Text(d.categoria[0])), title: Text(d.nome), subtitle: Text(d.categoria), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text('${d.valor.toStringAsFixed(0)} Kz', style: const TextStyle(fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { setState(() => despesas.remove(d)); _salvar(); })])))),
        if (despesas.isNotEmpty) TextButton(onPressed: () { setState(() => despesas.clear()); _salvar(); }, child: const Text('Limpar tudo')),
      ])),
      floatingActionButton: FloatingActionButton.extended(onPressed: _mostrarAdd, icon: const Icon(Icons.add), label: const Text('Despesa')),
    );
  }

  Widget _cardInfo(String titulo, String valor, Color cor) {
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [Text(titulo), const SizedBox(height: 4), Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cor))])));
  }
}
