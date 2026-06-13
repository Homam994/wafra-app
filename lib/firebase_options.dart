import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS    : return ios;
      default                    : return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey           : 'AIzaSyC0_JpDGpNTAb4rlMGwZeuPvtLsRY2PYEQ',
    appId            : '1:360975195166:android:ec7f7df84907c40e90a20f',
    messagingSenderId: '360975195166',
    projectId        : 'wafraa-app',
    storageBucket    : 'wafraa-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey           : 'AIzaSyC0_JpDGpNTAb4rlMGwZeuPvtLsRY2PYEQ',
    appId            : '1:360975195166:android:ec7f7df84907c40e90a20f',
    messagingSenderId: '360975195166',
    projectId        : 'wafraa-app',
    storageBucket    : 'wafraa-app.firebasestorage.app',
    iosBundleId      : 'com.wafra.wafra',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey           : 'AIzaSyAHzsmMrn8sHz6bO_EY3BokcxYTlqzHfRg',
    appId            : '1:207767040424:web:03663fe60033fd8f6eed9d',
    messagingSenderId: '207767040424',
    projectId        : 'wafraa-509ad',
    storageBucket    : 'wafraa-509ad.firebasestorage.app',
    authDomain       : 'wafraa-509ad.firebaseapp.com',
  );
}
