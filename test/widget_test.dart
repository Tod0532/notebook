// 动计笔记应用测试

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:thick_notepad/main.dart';

void main() {
  testWidgets('App starts successfully', (WidgetTester tester) async {
    // 构建应用
    await tester.pumpWidget(
      const ProviderScope(
        child: ThickNotepadApp(),
      ),
    );

    // 验证应用成功启动
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
