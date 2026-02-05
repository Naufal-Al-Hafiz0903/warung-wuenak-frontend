import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

enum AdminFieldType {
  text,
  intNum,
  doubleNum,
  password,
  dropdown,
  multiline,
  image,
}

class AdminDialogResult {
  final bool ok;
  final String message;
  const AdminDialogResult({required this.ok, required this.message});
}

class AdminFieldSpec {
  final String key;
  final String label;
  final AdminFieldType type;

  final bool required;
  final int flex;

  final List<String>? options; // dropdown
  final String? initialDropdownValue;

  /// ✅ NEW: prefill text untuk edit
  final String? initialTextValue;

  final int maxLines; // multiline/text

  // ✅ image options
  final bool imageRequired;
  final String imageHint;

  /// Maks size file gambar (bytes). Default 2MB.
  final int maxImageBytes;

  /// Maks lebar gambar saat picker (px). Default 1600.
  final double maxImageWidth;

  /// Kompres kualitas (0..100). Default 85.
  final int imageQuality;

  /// Custom validator tambahan (setelah default validator).
  final String? Function(String? v)? validator;

  const AdminFieldSpec({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.flex = 1,
    this.options,
    this.initialDropdownValue,
    this.initialTextValue, // ✅ NEW
    this.maxLines = 1,
    this.validator,

    // image
    this.imageRequired = false,
    this.imageHint = 'Pilih gambar (jpg/png/webp) • Max 2MB',
    this.maxImageBytes = 2 * 1024 * 1024,
    this.maxImageWidth = 1600,
    this.imageQuality = 85,
  });

  factory AdminFieldSpec.text(
    String key, {
    required String label,
    bool required = false,
    int flex = 1,
    String? initialValue, // ✅ NEW
    String? Function(String? v)? validator,
  }) {
    return AdminFieldSpec(
      key: key,
      label: label,
      type: AdminFieldType.text,
      required: required,
      flex: flex,
      initialTextValue: initialValue, // ✅ NEW
      validator: validator,
    );
  }

  factory AdminFieldSpec.password(
    String key, {
    required String label,
    bool required = false,
    int flex = 1,
    String? initialValue, // ✅ NEW (opsional)
    String? Function(String? v)? validator,
  }) {
    return AdminFieldSpec(
      key: key,
      label: label,
      type: AdminFieldType.password,
      required: required,
      flex: flex,
      initialTextValue: initialValue, // ✅ NEW
      validator: validator,
    );
  }

  factory AdminFieldSpec.multiline(
    String key, {
    required String label,
    bool required = false,
    int flex = 1,
    int maxLines = 3,
    String? initialValue, // ✅ NEW
    String? Function(String? v)? validator,
  }) {
    return AdminFieldSpec(
      key: key,
      label: label,
      type: AdminFieldType.multiline,
      required: required,
      flex: flex,
      maxLines: maxLines,
      initialTextValue: initialValue, // ✅ NEW
      validator: validator,
    );
  }

  factory AdminFieldSpec.intField(
    String key, {
    required String label,
    bool required = false,
    int flex = 1,
    String? initialValue, // ✅ NEW
    String? Function(String? v)? validator,
  }) {
    return AdminFieldSpec(
      key: key,
      label: label,
      type: AdminFieldType.intNum,
      required: required,
      flex: flex,
      initialTextValue: initialValue, // ✅ NEW
      validator: validator,
    );
  }

  factory AdminFieldSpec.doubleField(
    String key, {
    required String label,
    bool required = false,
    int flex = 1,
    String? initialValue, // ✅ NEW
    String? Function(String? v)? validator,
  }) {
    return AdminFieldSpec(
      key: key,
      label: label,
      type: AdminFieldType.doubleNum,
      required: required,
      flex: flex,
      initialTextValue: initialValue, // ✅ NEW
      validator: validator,
    );
  }

  factory AdminFieldSpec.dropdown(
    String key, {
    required String label,
    required List<String> options,
    bool required = false,
    int flex = 1,
    String? initialValue,
    String? Function(String? v)? validator,
  }) {
    return AdminFieldSpec(
      key: key,
      label: label,
      type: AdminFieldType.dropdown,
      required: required,
      flex: flex,
      options: options,
      initialDropdownValue: initialValue,
      validator: validator,
    );
  }

  /// ✅ Image
  factory AdminFieldSpec.image(
    String key, {
    required String label,
    bool required = false,
    String hint = 'Pilih gambar (jpg/png/webp) • Max 2MB',
    int maxBytes = 2 * 1024 * 1024,
    double maxWidth = 1600,
    int quality = 85,
  }) {
    return AdminFieldSpec(
      key: key,
      label: label,
      type: AdminFieldType.image,
      required: false,
      imageRequired: required,
      imageHint: hint,
      maxImageBytes: maxBytes,
      maxImageWidth: maxWidth,
      imageQuality: quality,
    );
  }
}

class AdminRepeatingGroupSpec {
  final String title;
  final int minRows;
  final List<AdminFieldSpec> fields;

  const AdminRepeatingGroupSpec({
    required this.title,
    this.minRows = 1,
    required this.fields,
  });
}

typedef AdminSubmitFn =
    Future<AdminDialogResult> Function(
      Map<String, dynamic> values,
      List<Map<String, dynamic>> groupRows,
    );

class AdminDialogSchema {
  final String title;
  final String submitLabel;
  final List<AdminFieldSpec> fields;
  final AdminRepeatingGroupSpec? group;
  final AdminSubmitFn onSubmit;

  const AdminDialogSchema({
    required this.title,
    required this.fields,
    required this.onSubmit,
    this.group,
    this.submitLabel = 'Simpan',
  });
}

class AdminEntityAddDialog extends StatefulWidget {
  final AdminDialogSchema schema;

  const AdminEntityAddDialog({super.key, required this.schema});

  @override
  State<AdminEntityAddDialog> createState() => _AdminEntityAddDialogState();
}

class _AdminEntityAddDialogState extends State<AdminEntityAddDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _dropdownValues = {};
  final Map<String, File?> _imageValues = {};

  // repeating group
  final List<Map<String, TextEditingController>> _groupControllers = [];
  final List<Map<String, String?>> _groupDropdownValues = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    for (final f in widget.schema.fields) {
      if (f.type == AdminFieldType.dropdown) {
        _dropdownValues[f.key] =
            f.initialDropdownValue ??
            (f.options?.isNotEmpty == true ? f.options!.first : null);
      } else if (f.type == AdminFieldType.image) {
        _imageValues[f.key] = null;
      } else {
        // ✅ NEW: controller prefill untuk edit
        _controllers[f.key] = TextEditingController(
          text: f.initialTextValue ?? '',
        );
      }
    }

    final g = widget.schema.group;
    if (g != null) {
      for (int i = 0; i < g.minRows; i++) {
        _addGroupRow(init: true);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final row in _groupControllers) {
      for (final c in row.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _addGroupRow({bool init = false}) {
    final g = widget.schema.group;
    if (g == null) return;

    final Map<String, TextEditingController> rowC = {};
    final Map<String, String?> rowD = {};

    for (final f in g.fields) {
      if (f.type == AdminFieldType.dropdown) {
        rowD[f.key] =
            f.initialDropdownValue ??
            (f.options?.isNotEmpty == true ? f.options!.first : null);
      } else {
        rowC[f.key] = TextEditingController();
      }
    }

    _groupControllers.add(rowC);
    _groupDropdownValues.add(rowD);

    if (!init) setState(() {});
  }

  void _removeGroupRow(int idx) {
    final g = widget.schema.group;
    if (g == null) return;
    if (_groupControllers.length <= g.minRows) return;

    final row = _groupControllers.removeAt(idx);
    _groupDropdownValues.removeAt(idx);

    for (final c in row.values) {
      c.dispose();
    }
    setState(() {});
  }

  // =========================
  // Validators & parsers
  // =========================
  String? _defaultValidator(AdminFieldSpec f, String? v) {
    if (f.required) {
      if (f.type == AdminFieldType.password) {
        if (v == null || v.isEmpty) return 'Wajib diisi';
      } else if (f.type == AdminFieldType.dropdown) {
        if (v == null || v.trim().isEmpty) return 'Wajib diisi';
      } else {
        if (v == null || v.trim().isEmpty) return 'Wajib diisi';
      }
    }

    if (f.type == AdminFieldType.intNum) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return f.required ? 'Wajib diisi' : null;
      if (int.tryParse(s) == null) return 'Harus angka';
    }

    if (f.type == AdminFieldType.doubleNum) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return f.required ? 'Wajib diisi' : null;
      if (double.tryParse(s) == null) return 'Harus angka';
    }

    return null;
  }

  String? _runValidator(AdminFieldSpec f, String? v) {
    final base = _defaultValidator(f, v);
    if (base != null) return base;
    return f.validator?.call(v);
  }

  dynamic _parseValue(AdminFieldSpec f, String? raw) {
    if (f.type == AdminFieldType.dropdown) return raw;
    if (f.type == AdminFieldType.password) return raw ?? '';

    final s = (raw ?? '').trim();

    switch (f.type) {
      case AdminFieldType.text:
      case AdminFieldType.multiline:
        return s;
      case AdminFieldType.intNum:
        if (s.isEmpty) return null;
        return int.parse(s);
      case AdminFieldType.doubleNum:
        if (s.isEmpty) return null;
        return double.parse(s);
      case AdminFieldType.password:
        return raw ?? '';
      case AdminFieldType.dropdown:
        return raw;
      case AdminFieldType.image:
        return _imageValues[f.key];
    }
  }

  // =========================
  // Image helpers
  // =========================
  bool _isAllowedImageExt(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.png') ||
        p.endsWith('.webp');
  }

  Future<File?> _pickAndValidateImage(AdminFieldSpec f) async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: f.imageQuality,
      maxWidth: f.maxImageWidth,
    );

    if (x == null) return null;

    if (!_isAllowedImageExt(x.path)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Format gambar harus jpg/jpeg/png/webp'),
          ),
        );
      }
      return null;
    }

    final file = File(x.path);

    final len = await file.length();
    if (len <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File gambar tidak valid / kosong')),
        );
      }
      return null;
    }

    if (len > f.maxImageBytes) {
      final mb = (f.maxImageBytes / (1024 * 1024)).toStringAsFixed(0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ukuran gambar terlalu besar. Maks ${mb}MB')),
        );
      }
      return null;
    }

    return file;
  }

  // =========================
  // Submit
  // =========================
  Future<void> _submit() async {
    if (_saving) return;

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final Map<String, dynamic> values = {};
    for (final f in widget.schema.fields) {
      if (f.type == AdminFieldType.dropdown) {
        values[f.key] = _dropdownValues[f.key];
      } else if (f.type == AdminFieldType.image) {
        values[f.key] = _imageValues[f.key];
      } else {
        values[f.key] = _parseValue(f, _controllers[f.key]?.text);
      }
    }

    final List<Map<String, dynamic>> groupRows = [];
    final g = widget.schema.group;
    if (g != null) {
      for (int i = 0; i < _groupControllers.length; i++) {
        final rowC = _groupControllers[i];
        final rowD = _groupDropdownValues[i];
        final Map<String, dynamic> row = {};

        for (final f in g.fields) {
          if (f.type == AdminFieldType.dropdown) {
            row[f.key] = rowD[f.key];
          } else {
            row[f.key] = _parseValue(f, rowC[f.key]?.text);
          }
        }
        groupRows.add(row);
      }
    }

    setState(() => _saving = true);

    final result = await widget.schema.onSubmit(values, groupRows);

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.ok) {
      Navigator.pop(context, result);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  // =========================
  // Field builders
  // =========================
  Widget _buildImageField(AdminFieldSpec f) {
    return _AdminImageFormField(
      label: f.label,
      hint: f.imageHint,
      enabled: !_saving,
      required: f.imageRequired,
      current: _imageValues[f.key],
      onPick: () async {
        if (_saving) return;

        final file = await _pickAndValidateImage(f);
        if (!mounted) return;

        setState(() => _imageValues[f.key] = file);
      },
      onClear: () {
        if (_saving) return;
        setState(() => _imageValues[f.key] = null);
      },
    );
  }

  Widget _buildDropdownField(AdminFieldSpec f) {
    final options = f.options ?? const <String>[];
    return DropdownButtonFormField<String>(
      value: _dropdownValues[f.key],
      decoration: InputDecoration(
        labelText: f.label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: options
          .map((x) => DropdownMenuItem(value: x, child: Text(x)))
          .toList(),
      onChanged: _saving
          ? null
          : (v) => setState(() => _dropdownValues[f.key] = v),
      validator: (v) => _runValidator(f, v),
    );
  }

  Widget _buildTextField(AdminFieldSpec f) {
    TextInputType? kb;
    bool obscure = false;

    if (f.type == AdminFieldType.intNum) kb = TextInputType.number;
    if (f.type == AdminFieldType.doubleNum) {
      kb = const TextInputType.numberWithOptions(decimal: true);
    }
    if (f.type == AdminFieldType.password) {
      obscure = true;
      kb = TextInputType.text;
    }

    return TextFormField(
      controller: _controllers[f.key],
      keyboardType: kb,
      obscureText: obscure,
      maxLines: f.type == AdminFieldType.multiline ? f.maxLines : 1,
      decoration: InputDecoration(
        labelText: f.label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: (v) => _runValidator(f, v),
    );
  }

  Widget _buildMainField(AdminFieldSpec f) {
    if (f.type == AdminFieldType.image) return _buildImageField(f);
    if (f.type == AdminFieldType.dropdown) return _buildDropdownField(f);
    return _buildTextField(f);
  }

  Widget _buildGroup() {
    final g = widget.schema.group;
    if (g == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            g.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(_groupControllers.length, (i) {
          final rowC = _groupControllers[i];
          final rowD = _groupDropdownValues[i];

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                ...g.fields.map((f) {
                  Widget field;
                  if (f.type == AdminFieldType.dropdown) {
                    final options = f.options ?? const <String>[];
                    field = DropdownButtonFormField<String>(
                      value: rowD[f.key],
                      decoration: InputDecoration(
                        labelText: f.label,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: options
                          .map(
                            (x) => DropdownMenuItem(value: x, child: Text(x)),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => rowD[f.key] = v),
                      validator: (v) => _runValidator(f, v),
                    );
                  } else {
                    TextInputType? kb;
                    if (f.type == AdminFieldType.intNum)
                      kb = TextInputType.number;
                    if (f.type == AdminFieldType.doubleNum) {
                      kb = const TextInputType.numberWithOptions(decimal: true);
                    }

                    field = TextFormField(
                      controller: rowC[f.key],
                      keyboardType: kb,
                      decoration: InputDecoration(
                        labelText: f.label,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => _runValidator(f, v),
                    );
                  }

                  return Expanded(
                    flex: f.flex,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: field,
                    ),
                  );
                }).toList(),
                IconButton(
                  tooltip: 'Hapus',
                  onPressed: _saving ? null : () => _removeGroupRow(i),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _saving ? null : () => _addGroupRow(),
            icon: const Icon(Icons.add),
            label: const Text('Tambah item'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.schema.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...widget.schema.fields.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildMainField(f),
                );
              }).toList(),
              _buildGroup(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: Text(_saving ? 'Menyimpan...' : widget.schema.submitLabel),
        ),
      ],
    );
  }
}

// ============================================================
// Image Form Field
// ============================================================
class _AdminImageFormField extends FormField<File?> {
  _AdminImageFormField({
    required String label,
    required String hint,
    required bool enabled,
    required bool required,
    required File? current,
    required Future<void> Function() onPick,
    required VoidCallback onClear,
  }) : super(
         initialValue: current,
         validator: (file) {
           if (required && file == null) return 'Wajib pilih gambar';
           return null;
         },
         builder: (state) {
           final file = state.value;

           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
               const SizedBox(height: 8),
               InkWell(
                 onTap: enabled
                     ? () async {
                         await onPick();
                         state.didChange(state.value);
                       }
                     : null,
                 borderRadius: BorderRadius.circular(12),
                 child: Container(
                   height: 120,
                   width: double.infinity,
                   padding: const EdgeInsets.all(10),
                   decoration: BoxDecoration(
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(color: Colors.black12),
                     color: const Color(0xFFF7F7FB),
                   ),
                   child: file == null
                       ? Row(
                           children: [
                             const Icon(Icons.image_rounded),
                             const SizedBox(width: 10),
                             Expanded(child: Text(hint)),
                             const Icon(Icons.upload_rounded),
                           ],
                         )
                       : Row(
                           children: [
                             ClipRRect(
                               borderRadius: BorderRadius.circular(10),
                               child: Image.file(
                                 file,
                                 width: 92,
                                 height: 92,
                                 fit: BoxFit.cover,
                               ),
                             ),
                             const SizedBox(width: 12),
                             Expanded(
                               child: Text(
                                 file.path.split(Platform.pathSeparator).last,
                                 maxLines: 2,
                                 overflow: TextOverflow.ellipsis,
                               ),
                             ),
                             IconButton(
                               tooltip: 'Hapus',
                               onPressed: !enabled
                                   ? null
                                   : () {
                                       onClear();
                                       state.didChange(null);
                                     },
                               icon: const Icon(Icons.close_rounded),
                             ),
                           ],
                         ),
                 ),
               ),
               if (state.errorText != null) ...[
                 const SizedBox(height: 6),
                 Text(
                   state.errorText!,
                   style: const TextStyle(
                     color: Colors.redAccent,
                     fontSize: 12,
                     fontWeight: FontWeight.w700,
                   ),
                 ),
               ],
             ],
           );
         },
       );
}
