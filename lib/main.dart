// lib/main.dart
import 'dart:convert';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Flashcard model
class Flashcard {
  int id;
  String question;
  String answer;
  List<String> tags;
  int reviewCount;
  int boxNumber;
  int lastReviewedEpoch;

  Flashcard({
    required this.id,
    required this.question,
    required this.answer,
    required this.tags,
    this.reviewCount = 0,
    this.boxNumber = 0,
    this.lastReviewedEpoch = 0,
  });

  factory Flashcard.fromMap(Map<String, dynamic> m) {
    return Flashcard(
      id: m['id'] as int,
      question: m['question'] as String,
      answer: m['answer'] as String,
      tags: (m['tags'] as List<dynamic>).map((e) => e as String).toList(),
      reviewCount: (m['reviewCount'] as int?) ?? 0,
      boxNumber: (m['boxNumber'] as int?) ?? 0,
      lastReviewedEpoch: (m['lastReviewedEpoch'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'question': question,
        'answer': answer,
        'tags': tags,
        'reviewCount': reviewCount,
        'boxNumber': boxNumber,
        'lastReviewedEpoch': lastReviewedEpoch,
      };
}

/// Leitner system + Hive persistence
class LeitnerSystem {
  static const int boxesCount = 5;
  final Map<int, Flashcard> _cards = {};
  final List<List<int>> _boxes = List.generate(boxesCount, (_) => []);
  late Box _box;
  int _nextId = 1;

  Future<void> init() async {
    _box = await Hive.openBox('flashcards_box_v1');

    final stored = _box.get('cards') as String?;
    if (stored != null) {
      final Map<String, dynamic> decoded =
          jsonDecode(stored) as Map<String, dynamic>;
      decoded.forEach((k, v) {
        final map = Map<String, dynamic>.from(v as Map);
        final card = Flashcard.fromMap(map);
        _cards[card.id] = card;
        _boxes[card.boxNumber].add(card.id);
        _nextId = max(_nextId, card.id + 1);
      });
    } else {
      await _populateInitial();
    }
  }

  /// 50 prebuilt DSA flashcards
  Future<void> _populateInitial() async {
    final initial = [
      Flashcard(
          id: 0,
          question: "What is a Queue?",
          answer: "FIFO linear data structure.",
          tags: ["queue", "ds"]),
      Flashcard(
          id: 0,
          question: "Enqueue operation?",
          answer: "Insert element at the back of the queue.",
          tags: ["queue", "operations"]),
      Flashcard(
          id: 0,
          question: "Dequeue operation?",
          answer: "Remove element from the front of the queue.",
          tags: ["queue", "operations"]),
      Flashcard(
          id: 0,
          question: "What is a Stack?",
          answer: "LIFO linear data structure.",
          tags: ["stack", "ds"]),
      Flashcard(
          id: 0,
          question: "Push operation?",
          answer: "Add element to the top of the stack.",
          tags: ["stack", "operations"]),
      Flashcard(
          id: 0,
          question: "Pop operation?",
          answer: "Remove element from the top of the stack.",
          tags: ["stack", "operations"]),
      Flashcard(
          id: 0,
          question: "What is a Linked List?",
          answer:
              "Sequence of nodes where each node points to the next node.",
          tags: ["linkedlist", "ds"]),
      Flashcard(
          id: 0,
          question: "Singly vs Doubly Linked List?",
          answer:
              "Singly: one pointer; Doubly: two pointers (prev & next).",
          tags: ["linkedlist", "types"]),
      Flashcard(
          id: 0,
          question: "What is a HashMap?",
          answer: "Key-value data structure using hashing.",
          tags: ["hashmap", "ds"]),
      Flashcard(
          id: 0,
          question: "Collision in HashMap?",
          answer: "When two keys hash to same index.",
          tags: ["hashmap", "concepts"]),
      Flashcard(
          id: 0,
          question: "What is Binary Tree?",
          answer: "Tree with max 2 children per node.",
          tags: ["tree", "ds"]),
      Flashcard(
          id: 0,
          question: "What is BST?",
          answer: "Binary Search Tree: left<root<right.",
          tags: ["bst", "tree"]),
      Flashcard(
          id: 0,
          question: "Tree traversal types?",
          answer: "Inorder, Preorder, Postorder.",
          tags: ["tree", "traversal"]),
      Flashcard(
          id: 0,
          question: "What is Graph?",
          answer: "Vertices connected by edges.",
          tags: ["graph", "ds"]),
      Flashcard(
          id: 0,
          question: "DFS vs BFS?",
          answer: "DFS: depth-first, BFS: breadth-first.",
          tags: ["graph", "traversal"]),
      Flashcard(
          id: 0,
          question: "What is Heap?",
          answer: "Complete binary tree with heap property.",
          tags: ["heap", "ds"]),
      Flashcard(
          id: 0,
          question: "Max Heap?",
          answer: "Parent >= children.",
          tags: ["heap", "concepts"]),
      Flashcard(
          id: 0,
          question: "Min Heap?",
          answer: "Parent <= children.",
          tags: ["heap", "concepts"]),
      Flashcard(
          id: 0,
          question: "What is Recursion?",
          answer: "Function calling itself.",
          tags: ["recursion", "ds"]),
      Flashcard(
          id: 0,
          question: "Base Case?",
          answer: "Condition to stop recursion.",
          tags: ["recursion", "concepts"]),
      Flashcard(
          id: 0,
          question: "What is Dynamic Programming?",
          answer: "Optimized recursive solution using memoization.",
          tags: ["dp", "ds"]),
      Flashcard(
          id: 0,
          question: "What is Memoization?",
          answer: "Storing results of subproblems.",
          tags: ["dp", "concepts"]),
      Flashcard(
          id: 0,
          question: "What is Time Complexity?",
          answer: "Measure of operations as function of input size.",
          tags: ["complexity", "ds"]),
      Flashcard(
          id: 0,
          question: "What is Space Complexity?",
          answer: "Measure of memory used as function of input size.",
          tags: ["complexity", "ds"]),
      Flashcard(
          id: 0,
          question: "Big O notation?",
          answer: "Asymptotic upper bound of algorithm.",
          tags: ["complexity", "notation"]),
      Flashcard(
          id: 0,
          question: "Big Theta notation?",
          answer: "Asymptotic tight bound.",
          tags: ["complexity", "notation"]),
      Flashcard(
          id: 0,
          question: "Big Omega notation?",
          answer: "Asymptotic lower bound.",
          tags: ["complexity", "notation"]),
      Flashcard(
          id: 0,
          question: "What is Queue using two stacks?",
          answer: "Implement queue with two stacks.",
          tags: ["queue", "stack"]),
      Flashcard(
          id: 0,
          question: "What is Circular Queue?",
          answer: "Queue connecting end to start.",
          tags: ["queue", "concepts"]),
      Flashcard(
          id: 0,
          question: "What is Deque?",
          answer: "Double-ended queue.",
          tags: ["queue", "concepts"]),
      Flashcard(
          id: 0,
          question: "What is Priority Queue?",
          answer: "Queue where elements have priorities.",
          tags: ["queue", "concepts"]),
      Flashcard(
          id: 0,
          question: "What is Graph cycle?",
          answer: "Path that starts and ends at same vertex.",
          tags: ["graph", "concepts"]),
      Flashcard(
          id: 0,
          question: "Topological Sort?",
          answer: "Ordering of DAG vertices.",
          tags: ["graph", "algorithm"]),
      Flashcard(
          id: 0,
          question: "Dijkstra's Algorithm?",
          answer: "Shortest path in weighted graph.",
          tags: ["graph", "algorithm"]),
      Flashcard(
          id: 0,
          question: "Floyd-Warshall Algorithm?",
          answer: "All-pairs shortest path.",
          tags: ["graph", "algorithm"]),
      Flashcard(
          id: 0,
          question: "Prim's Algorithm?",
          answer: "Minimum spanning tree.",
          tags: ["graph", "algorithm"]),
      Flashcard(
          id: 0,
          question: "Kruskal's Algorithm?",
          answer: "Minimum spanning tree using edges.",
          tags: ["graph", "algorithm"]),
      Flashcard(
          id: 0,
          question: "What is BFS in tree?",
          answer: "Level-order traversal.",
          tags: ["tree", "traversal"]),
      Flashcard(
          id: 0,
          question: "What is DFS in tree?",
          answer: "Preorder/inorder/postorder traversal.",
          tags: ["tree", "traversal"]),
      Flashcard(
          id: 0,
          question: "What is Hash Table load factor?",
          answer: "Number of elements / table size.",
          tags: ["hashmap", "concepts"]),
      Flashcard(
          id: 0,
          question: "Separate Chaining?",
          answer: "Collision handling with linked lists.",
          tags: ["hashmap", "concepts"]),
      Flashcard(
          id: 0,
          question: "Open Addressing?",
          answer: "Collision handling with probing.",
          tags: ["hashmap", "concepts"]),
      Flashcard(
          id: 0,
          question: "What is Trie?",
          answer: "Tree for strings.",
          tags: ["trie", "ds"]),
      Flashcard(
          id: 0,
          question: "Insert in Trie?",
          answer: "Add word character by character.",
          tags: ["trie", "operations"]),
      Flashcard(
          id: 0,
          question: "Search in Trie?",
          answer: "Check if word exists in Trie.",
          tags: ["trie", "operations"]),
      Flashcard(
          id: 0,
          question: "Delete in Trie?",
          answer: "Remove word from Trie.",
          tags: ["trie", "operations"]),
      Flashcard(
          id: 0,
          question: "What is HashSet?",
          answer: "Set data structure using hashing.",
          tags: ["hashset", "ds"]),
      Flashcard(
          id: 0,
          question: "Union-Find (Disjoint Set)?",
          answer: "Efficient connected components.",
          tags: ["ds", "graph"]),
    ];

    for (var c in initial) {
      addCard(c.question, c.answer, c.tags);
    }
  }

  Future<void> _persist() async {
    final out = <String, dynamic>{};
    _cards.forEach((k, v) => out['$k'] = v.toMap());
    await _box.put('cards', jsonEncode(out));
  }

  List<Flashcard> get allCards => _cards.values.toList();

  Map<String, int> getBoxStats() {
    final Map<String, int> stats = {};
    for (int i = 0; i < boxesCount; i++) stats['Box ${i + 1}'] = _boxes[i].length;
    return stats;
  }

  int get totalCards => _cards.length;

  Flashcard? getNextCard() {
    for (var box in _boxes) {
      if (box.isNotEmpty) {
        final id = box.removeAt(0);
        return _cards[id];
      }
    }
    return null;
  }

  Future<Flashcard> addCard(String q, String a, List<String> tags) async {
    final id = _nextId++;
    final card = Flashcard(id: id, question: q, answer: a, tags: tags, boxNumber: 0);
    _cards[id] = card;
    _boxes[0].add(id);
    await _persist();
    return card;
  }

  Future<void> editCard(int id, String q, String a, List<String> tags) async {
    final c = _cards[id];
    if (c == null) return;
    c.question = q;
    c.answer = a;
    c.tags = tags;
    await _persist();
  }

  Future<void> deleteCard(int id) async {
    if (!_cards.containsKey(id)) return;
    final c = _cards[id]!;
    _boxes[c.boxNumber].remove(id);
    _cards.remove(id);
    await _persist();
  }

  Future<void> reviewResult(Flashcard card, bool correct) async {
    card.reviewCount++;
    if (correct) {
      if (card.boxNumber < boxesCount - 1) card.boxNumber++;
    } else {
      card.boxNumber = 0;
    }
    card.lastReviewedEpoch = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    _boxes[card.boxNumber].add(card.id);
    await _persist();
  }

  List<Flashcard> searchByTag(String tag) {
    final t = tag.trim().toLowerCase();
    return _cards.values.where((c) => c.tags.map((e) => e.toLowerCase()).contains(t)).toList();
  }
}

/// Notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  tz.initializeTimeZones();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

Future<void> scheduleReminderForCard(int cardId, String title, String body, int daysFromNow) async {
  final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(days: daysFromNow));
  await flutterLocalNotificationsPlugin.zonedSchedule(
    cardId,
    title,
    body,
    scheduledDate,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'flashcard_reminder',
        'Flashcard reminders',
        channelDescription: 'Reminders to review flashcards',
      ),
    ),
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}

/// ----------------- Flutter UI -----------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await initNotifications();
  final system = LeitnerSystem();
  await system.init();
  await Hive.openBox('settings'); // for dark mode
  runApp(FlashcardApp(system: system));
}

class FlashcardApp extends StatefulWidget {
  final LeitnerSystem system;
  const FlashcardApp({Key? key, required this.system}) : super(key: key);

  @override
  State<FlashcardApp> createState() => _FlashcardAppState();
}

class _FlashcardAppState extends State<FlashcardApp> {
  late bool isDark;

  @override
  void initState() {
    super.initState();
    final box = Hive.box('settings');
    isDark = box.get('darkMode', defaultValue: false);
  }

  void toggleDarkMode() {
    setState(() {
      isDark = !isDark;
      Hive.box('settings').put('darkMode', isDark);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DSA Flashcards',
      theme: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: HomePage(system: widget.system, toggleDarkMode: toggleDarkMode, isDark: isDark),
    );
  }
}

class HomePage extends StatefulWidget {
  final LeitnerSystem system;
  final VoidCallback toggleDarkMode;
  final bool isDark;
  const HomePage({Key? key, required this.system, required this.toggleDarkMode, required this.isDark}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Flashcard? current;
  final qCtrl = TextEditingController();
  final aCtrl = TextEditingController();
  final tagCtrl = TextEditingController();
  List<Flashcard> searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  void _loadNext() {
    setState(() {
      current = widget.system.getNextCard();
    });
  }

  Future<void> _addOrEditDialog({Flashcard? edit}) async {
    if (edit != null) {
      qCtrl.text = edit.question;
      aCtrl.text = edit.answer;
      tagCtrl.text = edit.tags.join(', ');
    } else {
      qCtrl.clear();
      aCtrl.clear();
      tagCtrl.clear();
    }
  
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(edit == null ? 'Add Flashcard' : 'Edit Flashcard'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: qCtrl, decoration: InputDecoration(labelText: 'Question')),
              TextField(controller: aCtrl, decoration: InputDecoration(labelText: 'Answer')),
              TextField(controller: tagCtrl, decoration: InputDecoration(labelText: 'Tags (comma separated)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context,false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context,true), child: const Text('Save')),
        ],
      ),
    );
  
    if (res == true) {
      final tags = tagCtrl.text.split(',').map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList();
      if (edit == null) {
        final newCard = await widget.system.addCard(qCtrl.text.trim(), aCtrl.text.trim(), tags);
        await scheduleReminderForCard(newCard.id, 'Review: ${newCard.question}', 'Time to review', 1);
      } else {
        await widget.system.editCard(edit.id, qCtrl.text.trim(), aCtrl.text.trim(), tags);
      }
      setState((){});
    }
  }

  Future<void> _review(bool correct) async {
    if (current == null) return;
    final card = current!;
    await widget.system.reviewResult(card, correct);

    final days = card.boxNumber == 0 ? 1 : (1 << (card.boxNumber - 1));
    await scheduleReminderForCard(card.id, 'Review: ${card.question}', 'Time to review', days);

    _loadNext();
  }

   Widget _buildFlashcardWidget(Flashcard card) {
     return Slidable(
       key: ValueKey(card.id),
       endActionPane: ActionPane(
         motion: const DrawerMotion(),
         children: [
           SlidableAction(onPressed: (_) => _review(true), backgroundColor: Colors.green, icon: Icons.check, label: 'Correct'),
           SlidableAction(onPressed: (_) => _review(false), backgroundColor: Colors.red, icon: Icons.close, label: 'Wrong'),
           SlidableAction(onPressed: (_) { _addOrEditDialog(edit: card); }, backgroundColor: Colors.blue, icon: Icons.edit, label: 'Edit'),
         ],
       ),
       child: FlipCard(
         front: Card(
           elevation: 6,
           margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           child: Container(
             padding: const EdgeInsets.all(18),
             height: 200,
             child: Center(child: Text(card.question, style: const TextStyle(fontSize: 20))),
           ),
         ),
         back: Card(
           elevation: 6,
           margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           child: Container(
             padding: const EdgeInsets.all(18),
             height: 200,
             child: Center(child: Text(card.answer, style: const TextStyle(fontSize: 20))),
           ),
         ),
       ),
     );
   }

   Widget _buildDashboard() {
     final stats = widget.system.getBoxStats();
     final total = widget.system.totalCards.clamp(1, 999999);
     final sections = <PieChartSectionData>[];
     final colors = [Colors.deepPurple, Colors.indigo, Colors.teal, Colors.orange, Colors.red];
     int i = 0;
     stats.forEach((k,v){
       final value = v.toDouble();
       sections.add(PieChartSectionData(
         color: colors[i % colors.length],
         value: value,
         title: v > 0 ? '${v}' : '',
         radius: 50,
         titleStyle: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
       ));
       i++;
     });

     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
         SizedBox(height: 200, child: PieChart(PieChartData(sections: sections, sectionsSpace: 4, centerSpaceRadius: 40))),
         const SizedBox(height: 8),
         Padding(
           padding: const EdgeInsets.symmetric(horizontal: 16),
           child: Column(
             children: stats.entries.map((e){
               return Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(e.key),
                   Text('${e.value}'),
                 ],
               );
             }).toList(),
           ),
         ),
       ],
     );
   }

   Widget _buildAllCardsList() {
     final cards = widget.system.allCards;
     return Column(
       children: cards.map((c) => ListTile(
         title: Text(c.question),
         subtitle: Text('Box ${c.boxNumber+1} • Reviewed: ${c.reviewCount}'),
         trailing: PopupMenuButton<String>(
           onSelected: (s) async {
             if (s=='edit') {
               await _addOrEditDialog(edit: c);
               setState((){});
             } else if (s=='delete') {
               await widget.system.deleteCard(c.id);
               setState((){});
             }
           },
           itemBuilder: (_) => [
             const PopupMenuItem(value:'edit', child: Text('Edit')),
             const PopupMenuItem(value:'delete', child: Text('Delete')),
           ],
         ),
       )).toList(),
     );
   }

   void _onSearch(String q) {
     setState(() {
       if (q.trim().isEmpty) searchResults = [];
       else searchResults = widget.system.searchByTag(q);
     });
   }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DSA Flashcards'),
        actions: [
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.toggleDarkMode,
          ),
          IconButton(icon: const Icon(Icons.add), onPressed: () => _addOrEditDialog()),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () { setState((){}); }),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: ElevatedButton(onPressed: _loadNext, child: const Text('Next Card'))),
                  const SizedBox(width: 8),
                  if (current != null)
                    ElevatedButton(
                      onPressed: ()=>_review(true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Correct'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (current != null) _buildFlashcardWidget(current!),
            if (current == null)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text('No due cards — add more or wait for reminders!', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: ()=>_addOrEditDialog(), child: const Text('Add First Flashcard')),
                  ],
                ),
              ),
            const Divider(),
            _buildDashboard(),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(labelText: 'Search by tag (e.g., queue)'),
                onChanged: _onSearch,
              ),
            ),
            if (searchResults.isNotEmpty)
              Column(
                children: searchResults
                    .map((c) => ListTile(title: Text(c.question), subtitle: Text(c.answer)))
                    .toList(),
              ),
            const Divider(),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildAllCardsList()),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

