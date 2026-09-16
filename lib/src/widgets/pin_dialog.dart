import 'package:flutter/material.dart';

/// Pide un PIN numérico. Devuelve el PIN o null si se cancela.
Future<String?> showPinDialog(BuildContext context, {required String title}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _PinDialog(title: title),
  );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title});

  final String title;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(
          hintText: 'PIN',
          counterText: '',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final pin = _controller.text.trim();
            if (pin.isNotEmpty) Navigator.pop(context, pin);
          },
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}