import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';

class RandomWordList extends StatefulWidget {
  const RandomWordList({super.key});

  @override
  State<RandomWordList> createState() => _RandomWordListState();
}

class _RandomWordListState extends State<RandomWordList> {
  final _suggestions = <WordPair>[];
  final _biggerFont = const TextStyle();
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemBuilder: (context, i) {
        if (i.isOdd) return const Divider();
        final index = i ~/ 2;
        if (index >= _suggestions.length) {
          _suggestions.addAll(generateWordPairs().take(10));
        }
        return ListTile(
          title: Text(_suggestions[index].asPascalCase),
          //style: _biggerFont
        );
      },
    );
  }
}
