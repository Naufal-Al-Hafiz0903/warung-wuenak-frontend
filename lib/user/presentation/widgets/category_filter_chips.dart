import 'package:flutter/material.dart';
import '../../../models/category_model.dart';

class CategoryFilterChips extends StatelessWidget {
  final List<CategoryModel> categories;
  final int selectedId; // 0 = Semua
  final ValueChanged<int> onSelected;

  const CategoryFilterChips({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: 10,
        children: [
          ChoiceChip(
            label: const Text("Semua"),
            selected: selectedId == 0,
            onSelected: (_) => onSelected(0),
            selectedColor: cs.primary.withOpacity(.14),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w800,
              color: selectedId == 0 ? cs.primary : Colors.black87,
            ),
          ),
          ...categories.map((c) {
            final sel = selectedId == c.categoryId;
            return ChoiceChip(
              label: Text(c.categoryName),
              selected: sel,
              onSelected: (_) => onSelected(c.categoryId),
              selectedColor: cs.primary.withOpacity(.14),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w800,
                color: sel ? cs.primary : Colors.black87,
              ),
            );
          }),
        ],
      ),
    );
  }
}
