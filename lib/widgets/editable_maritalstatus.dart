import 'package:flutter/material.dart';

class EditableMaritalStatusTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String initialValue;
  final Function(String) onSave;
  final Future<List<DropdownMenuItem<String>>> Function() fetchMaritalStatus;

  const EditableMaritalStatusTile({
    super.key,
    required this.icon,
    required this.title,
    required this.initialValue,
    required this.onSave,
    required this.fetchMaritalStatus,
  });

  @override
  _EditableMaritalStatusTileState createState() => _EditableMaritalStatusTileState();
}

class _EditableMaritalStatusTileState extends State<EditableMaritalStatusTile> {
  bool _isEditing = false;
  String? _selectedMaritalStatus;

  @override
  void initState() {
    super.initState();
    // Do not set the initial value here
    _selectedMaritalStatus = null; // Start with no selected location
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
      future: widget.fetchMaritalStatus(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return DropdownButtonFormField<String>(
            initialValue: _selectedMaritalStatus, // Start with no selected value
            hint: const Text('Select Marital Status'),
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
                _selectedMaritalStatus = value;
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
    return Text(_selectedMaritalStatus ?? widget.initialValue); // Updated the display when no value is selected
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
        if (_selectedMaritalStatus != null) {
          widget.onSave(_selectedMaritalStatus!);
          setState(() {
            _isEditing = false;
          });
        }
      },
      child: const Text("Save"),
    );
  }
}
