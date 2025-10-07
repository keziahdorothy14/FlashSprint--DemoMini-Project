import 'dart:collection';
import 'package:hive/hive.dart';
import '../models/flashcard_model.dart';

class FlashcardSystem {
  final List<Queue<Flashcard>> boxes = List.generate(5, (_) => Queue<Flashcard>());
  late Box<Flashcard> _box;

  Future<void> init() async {
    _box = await Hive.openBox<Flashcard>('flashcards');
    if (_box.isEmpty) {
      await _populateInitialFlashcards();
    }
    for (var card in _box.values) {
      boxes[card.boxNumber].add(card); // updated
    }
  }

  Future<void> _populateInitialFlashcards() async {
    List<Flashcard> initialCards = [
      Flashcard(
          question: "What is a Queue in DSA?",
          answer: "A linear data structure following FIFO order.",
          tags: ["Queue", "DSA"]),
      Flashcard(
          question: "What is a HashMap?",
          answer: "A data structure that maps keys to values using a hash function.",
          tags: ["HashMap", "DSA"]),
      Flashcard(
          question: "What is a Stack?",
          answer: "A linear data structure following LIFO order.",
          tags: ["Stack", "DSA"]),
      Flashcard(
          question: "What is a Linked List?",
          answer: "A linear collection of nodes where each node points to the next.",
          tags: ["Linked List", "DSA"]),
      // Add more pre-filled flashcards as needed
    ];

    for (var card in initialCards) {
      await addFlashcard(card);
    }
  }

  Future<void> addFlashcard(Flashcard card) async {
    await _box.add(card);
    boxes[0].add(card);
  }

  Flashcard? getNextCard() {
    for (var box in boxes) {
      if (box.isNotEmpty) {
        return box.removeFirst();
      }
    }
    return null;
  }

  void reviewCard(Flashcard card, bool correct) {
    card.reviewCount++;
    if (correct && card.boxNumber < boxes.length - 1) {
      card.boxNumber++;
    } else {
      card.boxNumber = 0;
    }
    boxes[card.boxNumber].add(card);
    card.save();
  }

  Map<String, int> getBoxStats() {
    final stats = <String, int>{};
    for (int i = 0; i < boxes.length; i++) {
      stats['Box ${i + 1}'] = boxes[i].length;
    }
    return stats;
  }

  int get totalCards => boxes.fold(0, (sum, box) => sum + box.length);
}
