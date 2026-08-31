# Cross-platform packaging

The Linux and Android applications share the Flutter interface in `ui/` and call the original Ruby compiler. The Ruby source remains the canonical patching implementation.

## Linux AppImage

The AppDir contains:

- the Flutter Linux application;
- Ruby 2.7.8 under `runtime/`;
- VXAceTranslator and its modules under `app/`;
- a native RGSS3A extractor under `app/Resources/Tools/`.

The desktop bridge launches the bundled Ruby process and streams its output into the interface. No system Ruby installation is used.

## Android

Android uses the same Flutter screens and a method channel named `org.droidtop.vxace_translator/patcher`. The Android runner will embed CRuby 2.7.8 through JNI, invoke `VXAceTranslator.rb` in a worker, and forward progress to Flutter. Folder access is granted through Android's Storage Access Framework.

The Android runtime bridge and cross-platform RGSS3A extractor are the next implementation slice. They must be validated against RVData2 fixtures before full-game testing.
