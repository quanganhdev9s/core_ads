import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';

import '../../ads/demo_ads_controller.dart';
import '../../ads/native_ui_preview_catalog.dart';
import 'demo_screen_widgets.dart';
import 'native_ui_preview_screen.dart';

/// Danh sách toàn bộ native factory đã đăng ký để kiểm tra UI độc lập config.
class NativeUiGalleryScreen extends StatefulWidget {
  const NativeUiGalleryScreen({required this.ads, super.key});

  final DemoAdsController ads;

  @override
  State<NativeUiGalleryScreen> createState() => _NativeUiGalleryScreenState();
}

class _NativeUiGalleryScreenState extends State<NativeUiGalleryScreen> {
  static const groups = [
    'All',
    'Full',
    'Big',
    'Small',
    'Tiny',
    'Language',
    'Collap',
    'Card',
  ];

  String selectedGroup = 'All';

  String _groupFor(NativeAdType type) {
    final id = type.factoryId;
    if (id.startsWith('Full')) return 'Full';
    if (id.startsWith('Big')) return 'Big';
    if (id.startsWith('Small')) return 'Small';
    if (id.startsWith('Tiny')) return 'Tiny';
    if (id.startsWith('Language')) return 'Language';
    if (id.startsWith('Collap')) return 'Collap';
    return 'Card';
  }

  @override
  Widget build(BuildContext context) => DemoScreenScaffold(
    ads: widget.ads,
    title: 'Native UI gallery',
    body: (context) {
      final types = NativeUiPreviewCatalog.types
          .where(
            (type) =>
                selectedGroup == 'All' || _groupFor(type) == selectedGroup,
          )
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${NativeUiPreviewCatalog.types.length} native layouts',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            'Chọn một layout để mở trên màn hình riêng bằng native test ad. '
            'Full dùng AdsFullScreenNative; Collap dạng mở rộng dùng '
            'AdsCollapsibleNative để thử thu gọn.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final group in groups)
                ChoiceChip(
                  label: Text(group),
                  selected: selectedGroup == group,
                  onSelected: (_) => setState(() => selectedGroup = group),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final type in types)
            Card(
              child: ListTile(
                title: Text(type.factoryId),
                subtitle: Text(
                  '${_groupFor(type)} · '
                  '${NativeUiPreviewCatalog.placementFor(type).key}',
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        NativeUiPreviewScreen(ads: widget.ads, type: type),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
