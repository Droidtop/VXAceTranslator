import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class PatchRequest {
  const PatchRequest({
    required this.gamePath,
    required this.translationPath,
    required this.mods,
    this.forceDecrypt = true,
  });

  final String gamePath;
  final String translationPath;
  final List<String> mods;
  final bool forceDecrypt;

  Map<String, Object> toJson() => {
        'gamePath': gamePath,
        'translationPath': translationPath,
        'mods': mods,
        'forceDecrypt': forceDecrypt,
      };
}

abstract class PatchService {
  Stream<String> patch(PatchRequest request);

  factory PatchService.platform() => Platform.isAndroid
      ? const AndroidPatchService()
      : const DesktopPatchService();
}

class DesktopPatchService implements PatchService {
  const DesktopPatchService();

  @override
  Stream<String> patch(PatchRequest request) async* {
    final executable = Platform.environment['VXACE_TRANSLATOR_RUBY'] ??
        '${File(Platform.resolvedExecutable).parent.path}/runtime/bin/ruby';
    final script = Platform.environment['VXACE_TRANSLATOR_SCRIPT'] ??
        '${File(Platform.resolvedExecutable).parent.path}/app/VXAceTranslator.rb';
    final arguments = <String>[
      script,
      '-c',
      request.gamePath,
      '-i',
      request.translationPath,
      if (request.forceDecrypt) '--force-decrypt',
      for (final mod in request.mods) ...['--mod', mod],
    ];
    final process = await Process.start(executable, arguments);
    yield* StreamGroup.merge([
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      process.stderr.transform(utf8.decoder).transform(const LineSplitter()),
    ]);
    final exitCode = await process.exitCode;
    if (exitCode != 0) throw ProcessException(executable, arguments, 'Patcher failed', exitCode);
  }
}

class AndroidPatchService implements PatchService {
  const AndroidPatchService();
  static const _channel = MethodChannel('org.droidtop.vxace_translator/patcher');

  @override
  Stream<String> patch(PatchRequest request) async* {
    final stream = StreamController<String>();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'progress') stream.add(call.arguments as String);
    });
    try {
      await _channel.invokeMethod<void>('patch', request.toJson());
      await stream.close();
    } catch (error, trace) {
      stream.addError(error, trace);
      await stream.close();
    }
    yield* stream.stream;
  }
}

class StreamGroup {
  static Stream<T> merge<T>(Iterable<Stream<T>> streams) {
    final controller = StreamController<T>();
    var remaining = streams.length;
    for (final stream in streams) {
      stream.listen(controller.add, onError: controller.addError, onDone: () {
        remaining -= 1;
        if (remaining == 0) controller.close();
      });
    }
    return controller.stream;
  }
}
