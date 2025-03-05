import 'package:flutter/material.dart';

class EditableStateTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String initialValue;
  final Function(String) onSave;
  final Future<List<DropdownMenuItem<String>>> Function() fetchStates;

  const EditableStateTile({
    super.key,
    required this.icon,
    required this.title,
    required this.initialValue,
    required this.onSave,
    required this.fetchStates, required double fontSizeTitle, required double fontSizeSubtitle,
  });

  @override
  _EditableStateTileState createState() => _EditableStateTileState();
}

class _EditableStateTileState extends State<EditableStateTile> {
  bool _isEditing = false;
  String? _selectedStates;
  String? initialStates;

  @override
  void initState() {
    super.initState();
    _selectedStates = null;
    //initialLocation = widget.initialValue;
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
      future: widget.fetchStates(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return
            DropdownButtonFormField<String>(
              value: _selectedStates,
              hint: const Text('Select States'),
              decoration: const InputDecoration(
                labelText:null,
                // contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              ),
              items: snapshot.data!.map((item) {
                return DropdownMenuItem<String>(
                  value: item.value,
                  child: Container(
                    //height:150,// Container is now the child of DropdownMenuItem
                    margin: const EdgeInsets.symmetric(vertical: 2.5), // Add padding to Container
                    child: item.child,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStates = value;
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
    return Text(_selectedStates ?? widget.initialValue);
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
        if (_selectedStates != null) {
          widget.onSave(_selectedStates!);
          setState(() {
            _isEditing = false;
          });
        }
      },
      child: const Text("Save"),
    );
  }
}