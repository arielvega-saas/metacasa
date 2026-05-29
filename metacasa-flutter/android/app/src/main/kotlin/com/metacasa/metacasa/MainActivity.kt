package com.metacasa.metacasa

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth (biometría) requiere una FragmentActivity en Android para poder
// mostrar el BiometricPrompt. Por eso extendemos FlutterFragmentActivity en
// lugar del FlutterActivity default. Sin esto, `authenticate()` tira
// "no_fragment_activity" en runtime.
class MainActivity : FlutterFragmentActivity()
