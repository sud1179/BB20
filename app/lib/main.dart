import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const dataUrl =
    'https://raw.githubusercontent.com/sud1179/BB20/main/data.json';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});            //test
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'Big Boss Popularity',
        theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
        home: const Home(),
      );
}

class Row_ {
  final String name;
  final List<double> days;
  Row_(this.name, this.days);
  double get today => days.last;
  double get week => days.sublist(7).fold(0, (a, b) => a + b);
  double get prevWeek => days.sublist(0, 7).fold(0, (a, b) => a + b);
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool weekly = false;
  List<Row_> rows = [];
  List<String> labels = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final r = await http.get(Uri.parse(dataUrl));
      final m = jsonDecode(r.body)['contestants'] as Map<String, dynamic>;
      final now = DateTime.now();
      final keys = List.generate(14, (i) {
        final d = now.subtract(Duration(days: 13 - i));
        return d.toIso8601String().substring(0, 10);
      });
      labels = keys.sublist(7).map((k) => k.substring(8)).toList();
      rows = m.entries
          .map((e) => Row_(
              e.key,
              keys
                  .map((k) => ((e.value[k]?['score']) ?? 0).toDouble() as double)
                  .toList()))
          .toList();
      error = null;
    } catch (e) {
      error = 'Could not load data';
    }
    setState(() => loading = false);
  }

  Color heat(double v, double max) =>
      Color.lerp(Colors.grey.shade100, Colors.deepOrange, max == 0 ? 0 : (v / max).clamp(0, 1))!;

  @override
  Widget build(BuildContext context) {
    final sorted = [...rows]..sort((a, b) =>
        (weekly ? b.week : b.today).compareTo(weekly ? a.week : a.today));
    final max = rows.fold<double>(
        0, (a, r) => r.days.sublist(7).fold(a, (x, y) => y > x ? y : x));
    return Scaffold(
      appBar: AppBar(title: const Text('Big Boss Popularity'), actions: [
        IconButton(onPressed: load, icon: const Icon(Icons.refresh))
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : ListView(padding: const EdgeInsets.all(12), children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Daily')),
                      ButtonSegment(value: true, label: Text('Weekly')),
                    ],
                    selected: {weekly},
                    onSelectionChanged: (s) => setState(() => weekly = s.first),
                  ),
                  const SizedBox(height: 12),
                  ...sorted.asMap().entries.map((e) {
                    final r = e.value;
                    final up = r.week >= r.prevWeek;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${e.key + 1}')),
                        title: Text(r.name),
                        subtitle: Text(weekly ? 'Last 7 days' : 'Today'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text((weekly ? r.week : r.today).toStringAsFixed(1),
                              style: Theme.of(context).textTheme.titleMedium),
                          Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                              color: up ? Colors.green : Colors.red, size: 18),
                        ]),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Text('Last 7 days (heatmap)',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Table(
                      defaultColumnWidth: const FixedColumnWidth(44),
                      columnWidths: const {0: FixedColumnWidth(110)},
                      children: [
                        TableRow(children: [
                          const SizedBox(),
                          ...labels.map((l) => Center(child: Text(l)))
                        ]),
                        ...sorted.map((r) => TableRow(children: [
                              Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(r.name, overflow: TextOverflow.ellipsis)),
                              ...r.days.sublist(7).map((v) => Container(
                                  height: 32,
                                  margin: const EdgeInsets.all(1),
                                  color: heat(v, max),
                                  alignment: Alignment.center,
                                  child: Text(v.round().toString(),
                                      style: const TextStyle(fontSize: 11)))),
                            ])),
                      ],
                    ),
                  ),
                ]),
    );
  }
}
