import 'package:flutter/material.dart';

class WorksForm extends StatefulWidget {
  const WorksForm({super.key});

  @override
  State<WorksForm> createState() => _WorksFormState();
}

class _WorksFormState extends State<WorksForm> {
  final GlobalKey<FormState> _worksFormKey = GlobalKey<FormState>();
  final TextEditingController controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _worksFormKey,
      child: Column(
        children: <Widget>[
          TextFormField(
            controller: controller,
            decoration: const InputDecoration(
                hintText: 'Arbeitsbezeichnung oder Sammelbegriff'),
            validator: (String? value) {
              if (value == null || value.isEmpty) {
                return 'Bitte eine Bezeichnung angeben';
              }
              return null;
            },
          ),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 15.0),
              child: ElevatedButton(
                onPressed: () {
                  if (_worksFormKey.currentState!.validate()) {
                    var text = controller.text;
                    var i = 0;
                  }
                },
                child: const Text('Hinzufügen'),
              ))
        ],
      ),
    );
  }
}
