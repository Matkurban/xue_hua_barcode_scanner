import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_barcode_scanner/xue_hua_barcode_scanner.dart';

import '../widgets/section_card.dart';

/// 演示多输入源菜单与单输入源隐藏，不启动相机、也不在进入时弹出菜单。
class InputSourceMenuDemoPage extends StatefulWidget {
  /// Creates the input-source menu demonstration page.
  const InputSourceMenuDemoPage({super.key});

  /// Several cameras. The first item is the default device.
  static const List<CameraInputSource> multipleSources = <CameraInputSource>[
    CameraInputSource(id: 'back', label: '后置相机', facing: CameraFacing.back),
    CameraInputSource(id: 'front', label: '前置相机', facing: CameraFacing.front),
    CameraInputSource(id: 'usb', label: '外接相机', facing: CameraFacing.external),
  ];

  /// A device that only has one input.
  static const List<CameraInputSource> singleSource = <CameraInputSource>[
    CameraInputSource(id: 'only', label: '内置相机', facing: CameraFacing.back),
  ];

  @override
  State<InputSourceMenuDemoPage> createState() =>
      _InputSourceMenuDemoPageState();
}

class _InputSourceMenuDemoPageState extends State<InputSourceMenuDemoPage> {
  CameraInputSource _selected = InputSourceMenuDemoPage.multipleSources.first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('输入源选择')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            '标准扫码页进入后直接打开平台默认相机，不会自动弹出选择菜单。'
            '只有存在多个输入源时，右上角按钮才会出现；由用户点击后再用菜单切换。',
          ),
          const SizedBox(height: 16),
          ExampleSectionCard(
            icon: Icons.cameraswitch_rounded,
            title: '多个输入源',
            subtitle: '默认设备已选中。点击右侧按钮后才会打开菜单。',
            child: _SourcePreviewBar(
              sources: InputSourceMenuDemoPage.multipleSources,
              selected: _selected,
              statusKey: const ValueKey<String>('xh_demo_active_source'),
              onSelected: (CameraInputSource source) {
                setState(() => _selected = source);
              },
            ),
          ),
          const SizedBox(height: 16),
          ExampleSectionCard(
            icon: Icons.videocam_outlined,
            title: '单个输入源',
            subtitle: '只有一个输入源时不显示选择入口，也不会弹出空菜单。',
            child: _SourcePreviewBar(
              sources: InputSourceMenuDemoPage.singleSource,
              selected: InputSourceMenuDemoPage.singleSource.first,
              statusKey: const ValueKey<String>('xh_single_source_hidden'),
              onSelected: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}

class _SourcePreviewBar extends StatelessWidget {
  const _SourcePreviewBar({
    required this.sources,
    required this.selected,
    required this.statusKey,
    required this.onSelected,
  });

  final List<CameraInputSource> sources;
  final CameraInputSource selected;
  final Key statusKey;
  final ValueChanged<CameraInputSource> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('当前输入源：${selected.label}', key: statusKey),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text('默认预览', style: TextStyle(color: Colors.white)),
                ),
                XueHuaCameraSourceButton(
                  sources: sources,
                  activeSourceId: selected.id,
                  tooltip: '选择输入源',
                  onSelected: onSelected,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
