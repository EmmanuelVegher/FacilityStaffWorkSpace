import 'package:flutter/material.dart';

class EditableGenderTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String initialValue;
  final Function(String) onSave;
  final Future<List<DropdownMenuItem<String>>> Function() fetchGender;

  const EditableGenderTile({
    super.key,
    required this.icon,
    required this.title,
    required this.initialValue,
    required this.onSave,
    required this.fetchGender,
  });

  @override
  _EditableGenderTileState createState() => _EditableGenderTileState();
}

class _EditableGenderTileState extends State<EditableGenderTile> {
  bool _isEditing = false;
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    // Do not set the initial value here
    _selectedGender = null; // Start with no selected location
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(widget.icon),
      title: Text(widget.title),
      subtitle: _isEditing ? buildDropdown() : buildText(),
      trailing: _isEditing ? buildSaveButton() : buildEditIcon(),
    );
  }

  Widget buildDropdown() {
    return FutureBuilder<List<DropdownMenuItem<String>>>(
      future: widget.fetchGender(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return DropdownButtonFormField<String>(
            initialValue: _selectedGender, // Start with no selected value
            hint: const Text('Select Gender'),
            decoration: const InputDecoration(
              labelText: null,
            ),
            items: snapshot.data!.map((item) {
              return DropdownMenuItem<String>(
                value: item.value,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2.5),
                  child: item.child,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedGender = value;
              });
            },
            isExpanded: true,
          );
        } else {
          return const CircularProgressIndicator();
        }
      },
    );
  }

  Widget buildText() {
    return Text(_selectedGender ?? widget.initialValue); // Updated the display when no value is selected
  }

  Widget buildEditIcon() {
    return IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () {
        setState(() {
          _isEditing = true;
        });
      },
    );
  }

  Widget buildSaveButton() {
    return TextButton(
      onPressed: () {
        if (_selectedGender != null) {
          widget.onSave(_selectedGender!);
          setState(() {
            _isEditing = false;
          });
        }
      },
      child: const Text("Save"),
    );
  }
}
