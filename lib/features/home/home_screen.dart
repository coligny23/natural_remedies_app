import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/topic_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('Learn'),
            stretch: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(children: const [
              SectionHeader('Continue'),
              TopicCard(title: 'Natural Remedies Basics', subtitle: 'Pick up where you left off', id: 'basics'),
              SizedBox(height: 12),
              SectionHeader('Recommended'),
              TopicCard(title: 'Cold & Flu', subtitle: 'Short reads · 5–7 min', id: 'cold-flu'),
              SizedBox(height: 12),
              TopicCard(title: 'Digestive Health', subtitle: 'Evidence-based tips', id: 'digestive'),
            ]),
          ),
        ],
      ),
    );
  }
}
