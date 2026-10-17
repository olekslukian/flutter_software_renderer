import 'dart:io';

import 'package:software_engine/testing/file_asset_loader.dart';
import 'package:test/test.dart';

void main() {
  group('FileAssetLoader', () {
    const loader = FileAssetLoader('../../assets');

    test('reads a file relative to its root', () async {
      final text = await loader.loadString('models/penger.obj');

      expect(text, contains('\nv '));
    });

    test('fails for a missing asset', () {
      expect(
        loader.loadString('models/missing.obj'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
