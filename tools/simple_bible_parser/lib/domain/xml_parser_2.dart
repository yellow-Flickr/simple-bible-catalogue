class Root {
  final Bible bible;

  Root({required this.bible});
}

class Bible {
  final FieldItem fieldItem;
  final List<Testament> testament;

  Bible({required this.fieldItem, required this.testament});
}

class Testament {
  final FieldItem2 fieldItem;
  final List<Book> book;

  Testament({required this.fieldItem, required this.book});
}

class Book {
  final FieldItem3 fieldItem;
  final List<Chapter> chapter;

  Book({required this.fieldItem, required this.chapter});
}

class Chapter {
  final FieldItem4 fieldItem;
  final List<Verse> verse;

  Chapter({required this.fieldItem, required this.verse});
}

class Verse {
  final String fieldItem;
  final FieldItem5 fieldItem2;

  Verse({required this.fieldItem, required this.fieldItem2});
}

class FieldItem5 {
  final String number;

  FieldItem5({required this.number});
}

class FieldItem4 {
  final String number;

  FieldItem4({required this.number});
}

class FieldItem3 {
  final String number;

  FieldItem3({required this.number});
}

class FieldItem2 {
  final String name;

  FieldItem2({required this.name});
}

class FieldItem {
  final String name;

  FieldItem({required this.name});
}
