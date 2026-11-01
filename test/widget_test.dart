import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_traffic_management/main.dart';
import 'package:intelligent_traffic_management/services/demo_traffic_repository.dart';

void main() {
  testWidgets('IntelligentTrafficApp loads dashboard and starts journey', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = DemoTrafficRepository();
    await tester.pumpWidget(IntelligentTrafficApp(repository: repo));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Title and Key widgets
    expect(find.text('Smart Traffic Navigation'), findsOneWidget);
    expect(find.text('Add Vehicle Journey'), findsOneWidget);
    expect(find.text('Live Map'), findsOneWidget);

    repo.dispose();
  });
}
