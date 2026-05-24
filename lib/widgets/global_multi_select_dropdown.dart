import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlobalMultiSelectDropdown<T> extends StatelessWidget {
  final List<T> items;
  final List<T> selectedItems;
  final String title;
  final String Function(T) labelBuilder;
  final Function(List<T>) onChanged;
  final Color primaryColor;
  final bool isAllOptionEnabled;
  final String allOptionLabel;

  const GlobalMultiSelectDropdown({
    super.key,
    required this.items,
    required this.selectedItems,
    required this.title,
    required this.labelBuilder,
    required this.onChanged,
    this.primaryColor = const Color(0xFF5C1A2E), // Maroon
    this.isAllOptionEnabled = true,
    this.allOptionLabel = "Select All",
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final List<T>? result = await showDialog<List<T>>(
          context: context,
          builder: (ctx) {
            return _GlobalMultiSelectDialog<T>(
              items: items,
              initialSelectedItems: selectedItems,
              title: title,
              labelBuilder: labelBuilder,
              primaryColor: primaryColor,
              isAllOptionEnabled: isAllOptionEnabled,
              allOptionLabel: allOptionLabel,
            );
          },
        );

        if (result != null) {
          onChanged(result);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.05),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(color: primaryColor, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                selectedItems.length == items.length && items.isNotEmpty
                    ? "All ${title.replaceFirst('Select ', '')} Selected"
                    : selectedItems.isEmpty
                        ? title
                        : "${selectedItems.length} Selected",
                style: GoogleFonts.poppins(color: primaryColor, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: primaryColor),
          ],
        ),
      ),
    );
  }
}

class _GlobalMultiSelectDialog<T> extends StatefulWidget {
  final List<T> items;
  final List<T> initialSelectedItems;
  final String title;
  final String Function(T) labelBuilder;
  final Color primaryColor;
  final bool isAllOptionEnabled;
  final String allOptionLabel;

  const _GlobalMultiSelectDialog({
    super.key,
    required this.items,
    required this.initialSelectedItems,
    required this.title,
    required this.labelBuilder,
    required this.primaryColor,
    required this.isAllOptionEnabled,
    required this.allOptionLabel,
  });

  @override
  State<_GlobalMultiSelectDialog<T>> createState() => _GlobalMultiSelectDialogState<T>();
}

class _GlobalMultiSelectDialogState<T> extends State<_GlobalMultiSelectDialog<T>> {
  late List<T> _tempSelectedItems;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tempSelectedItems = List.from(widget.initialSelectedItems);
  }

  bool get _isAllSelected {
    if (widget.items.isEmpty) return false;
    // We check if all items filtered by search (if implement search) or ALL items are selected.
    // Usually "Select All" refers to all available items.
    return _tempSelectedItems.length == widget.items.length;
  }

  void _toggleAll(bool? value) {
    setState(() {
      if (value == true) {
        _tempSelectedItems = List.from(widget.items);
      } else {
        _tempSelectedItems.clear();
      }
    });
  }

  void _toggleItem(T item, bool? value) {
    setState(() {
      if (value == true) {
        if (!_tempSelectedItems.contains(item)) {
          _tempSelectedItems.add(item);
        }
      } else {
        _tempSelectedItems.remove(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.items.where((item) {
      return widget.labelBuilder(item).toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return AlertDialog(
      title: Text(widget.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      contentPadding: const EdgeInsets.only(top: 12.0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
            ),
            
            if (widget.isAllOptionEnabled && _searchQuery.isEmpty) ...[
              CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  widget.allOptionLabel,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: widget.primaryColor),
                ),
                value: _isAllSelected,
                activeColor: widget.primaryColor,
                onChanged: _toggleAll,
              ),
              const Divider(),
            ],

            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  final isSelected = _tempSelectedItems.contains(item);
                  return CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(widget.labelBuilder(item), style: GoogleFonts.poppins()),
                    value: isSelected,
                    activeColor: widget.primaryColor,
                    onChanged: (val) => _toggleItem(item, val),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("CANCEL", style: TextStyle(color: Colors.grey[700])),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: widget.primaryColor),
          onPressed: () => Navigator.pop(context, _tempSelectedItems),
          child: Text("CONFIRM", style: GoogleFonts.poppins(color: Colors.white)),
        ),
      ],
    );
  }
}
