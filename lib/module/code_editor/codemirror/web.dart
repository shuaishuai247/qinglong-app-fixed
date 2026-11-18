import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'impl.dart';

/// Web 占位实现：项目仅支持移动端，此处仅为满足条件导入，保证 web 目标可编译。
class CodeMirrorView extends CodeMirrorViewImpl {
  final CodeMirrorOptions options;

  final ValueChanged<EditorController> onCreate;

  final Function(String val) onValue;

  const CodeMirrorView({
    Key? key,
    required this.options,
    required this.onCreate,
    required this.onValue,
  }) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return CodeMirrorViewState();
  }
}

class CodeMirrorViewState extends CodeMirrorViewImplState<CodeMirrorView> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
