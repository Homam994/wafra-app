@echo off
echo Building Wafra APK...
cd android
call gradlew assembleRelease
cd ..
copy android\app\build\outputs\apk\release\app-release.apk wafra.apk
echo.
echo Done! APK saved as: wafra.apk