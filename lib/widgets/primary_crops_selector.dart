import 'package:flutter/material.dart';

class PrimaryCropsSelector extends StatefulWidget {
  final List<String> selectedCrops;
  final List<String> allCrops;
  final ValueChanged<List<String>> onCropsSelected;

  const PrimaryCropsSelector({
    super.key,
    required this.selectedCrops,
    required this.allCrops,
    required this.onCropsSelected,
  });

  @override
  State<PrimaryCropsSelector> createState() => _PrimaryCropsSelectorState();
}

class _PrimaryCropsSelectorState extends State<PrimaryCropsSelector> {
  late List<String> _tempSelected;

  @override
  void initState() {
    super.initState();
    _tempSelected = List<String>.from(widget.selectedCrops);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Primary Crops'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children:
              widget.allCrops.map((crop) {
                return CheckboxListTile(
                  value: _tempSelected.contains(crop),
                  title: Text(crop),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _tempSelected.add(crop);
                      } else {
                        _tempSelected.remove(crop);
                      }
                    });
                  },
                );
              }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onCropsSelected(_tempSelected);
            Navigator.pop(context);
          },
          child: const Text('Done'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
