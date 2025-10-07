import 'package:hive/hive.dart';
part 'flashcard_model.g.dart';

@HiveType(typeId: 0)
class Flashcard extends HiveObject {
  @HiveField(0)
  String question;

  @HiveField(1)
  String answer;

  @HiveField(2)
  List<String> tags;

  @HiveField(3)
  int reviewCount;

  @HiveField(4)
  int boxNumber; // renamed from 'box' to 'boxNumber'

  Flashcard({
    required this.question,
    required this.answer,
    required this.tags,
    this.reviewCount = 0,
    this.boxNumber = 0,
  });
}
