import 'package:flutter/material.dart';

import 'token_store.dart';

/// A dropdown that lets the user pick which stored token a repository should
/// use, or "Auto" to fall back to org/owner matching.
///
/// Reports the selected token id (or null for "Auto") via [onChanged].
class TokenOverrideField extends StatefulWidget {
  const TokenOverrideField({
    super.key,
    required this.provider,
    required this.initialTokenId,
    required this.onChanged,
  });

  final String provider;
  final String? initialTokenId;

  /// Called with the selected token id, or null when "Auto" is chosen.
  final ValueChanged<String?> onChanged;

  @override
  State<TokenOverrideField> createState() => _TokenOverrideFieldState();
}

class _TokenOverrideFieldState extends State<TokenOverrideField> {
  List<TokenInfo> _tokens = [];
  String _selected = ''; // '' = Auto
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialTokenId ?? '';
    _load();
  }

  Future<void> _load() async {
    final tokens = await TokenStore.getTokensForProvider(widget.provider);
    if (!mounted) return;
    setState(() {
      _tokens = tokens;
      // If the previously-assigned token no longer exists, revert to Auto.
      if (_selected.isNotEmpty && !tokens.any((t) => t.id == _selected)) {
        _selected = '';
        widget.onChanged(null);
      }
      _loaded = true;
    });
  }

  /// A value guaranteed to be present in the dropdown's items, so the
  /// [DropdownButtonFormField] assertion never trips before tokens load.
  String get _safeValue =>
      _tokens.any((t) => t.id == _selected) ? _selected : '';

  String _label(TokenInfo token) => token.isDefault
      ? '${token.label} (default)'
      : '${token.label} (${token.scope})';

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _safeValue,
      decoration: const InputDecoration(
        labelText: 'Token',
        border: OutlineInputBorder(),
        helperText:
            'Auto uses the token whose scope matches the owner/org, else the '
            'default token.',
      ),
      items: [
        const DropdownMenuItem(
          value: '',
          child: Text('Auto (match by owner/org)'),
        ),
        ..._tokens.map(
          (token) => DropdownMenuItem(
            value: token.id,
            child: Text(_label(token)),
          ),
        ),
      ],
      onChanged: _loaded
          ? (value) {
              setState(() => _selected = value ?? '');
              widget.onChanged(
                (value == null || value.isEmpty) ? null : value,
              );
            }
          : null,
    );
  }
}
