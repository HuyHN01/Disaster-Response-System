// lib/features/admin_panel/rescue_stations/presentation/widgets/location_autocomplete_field.dart

import 'dart:async';

import 'package:disaster_response_app/core/services/routing/open_route_service.dart';
import 'package:flutter/material.dart';

class LocationAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<LocationResult> onSelected;

  const LocationAutocompleteField({
    super.key,
    required this.controller,
    required this.onSelected,
  });

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  Timer? _debounceTimer;
  LocationResult? _lastSelection;
  TextEditingController? _innerFieldCtrl;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncCtrl);
  }

  void _syncCtrl() {
    if (_innerFieldCtrl != null &&
        _innerFieldCtrl!.text != widget.controller.text) {
      _innerFieldCtrl!.text = widget.controller.text;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncCtrl);
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<LocationResult>(
          displayStringForOption: (LocationResult option) => option.toString(),
          optionsBuilder: (TextEditingValue textEditingValue) {
            final query = textEditingValue.text.trim();
            if (query.isEmpty || query == _lastSelection?.toString()) {
              return const Iterable<LocationResult>.empty();
            }

            if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
            final completer = Completer<Iterable<LocationResult>>();

            _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
              if (!mounted) {
                completer.complete([]);
                return;
              }
              final results = await OpenRouteService.instance.searchAddress(
                query,
              );
              completer.complete(results);
            });

            return completer.future;
          },
          onSelected: (LocationResult selection) {
            _lastSelection = selection;
            widget.controller.text = selection.toString();
            widget.onSelected(selection);
          },
          fieldViewBuilder:
              (
                BuildContext context,
                TextEditingController fieldController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted,
              ) {
                _innerFieldCtrl = fieldController;
                // Khi form khởi tạo, truyền dữ liệu từ widget cha sang
                if (fieldController.text.isEmpty &&
                    widget.controller.text.isNotEmpty) {
                  fieldController.text = widget.controller.text;
                }

                // Lắng nghe thay đổi do người dùng gõ tay
                fieldController.addListener(() {
                  if (widget.controller.text != fieldController.text) {
                    widget.controller.text = fieldController.text;
                    // Nếu người dùng nhập tay (không chọn từ danh sách) -> Clear _lastSelection
                    _lastSelection = null;
                  }
                });

                return TextField(
                  controller: fieldController,
                  focusNode: focusNode,
                  onSubmitted: (_) => onFieldSubmitted(),
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ, vị trí (Khuyến nghị gõ tìm kiếm)',
                    border: OutlineInputBorder(),
                    hintText: 'VD: Phú An, Hồ Chí Minh',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                );
              },
          optionsViewBuilder:
              (
                BuildContext context,
                AutocompleteOnSelected<LocationResult> onSelected,
                Iterable<LocationResult> options,
              ) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(8),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 250,
                        maxWidth: constraints
                            .maxWidth, // Căn chỉnh width bằng với input cha
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            leading: const Icon(
                              Icons.location_on_outlined,
                              color: Colors.red,
                            ),
                            title: Text(
                              option.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: option.address.isNotEmpty
                                ? Text(
                                    option.address,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: () {
                              onSelected(option);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
        );
      },
    );
  }
}
