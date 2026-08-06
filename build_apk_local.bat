@echo off
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
set "ANDROID_HOME=C:\Users\nksil\AppData\Local\Android\Sdk"
set "ANDROID_SDK_ROOT=C:\Users\nksil\AppData\Local\Android\Sdk"
set "ANDROID_USER_HOME=E:\vervestride\.android"
set "GRADLE_USER_HOME=E:\vervestride\.gradle"
set "GRADLE_OPTS=-Xmx2g -Dorg.gradle.jvmargs=-Xmx2g -Dorg.gradle.daemon=false"
set "PATH=%JAVA_HOME%\bin;%PATH%"
if not exist "E:\vervestride\.android" mkdir "E:\vervestride\.android"
if not exist "E:\vervestride\.gradle" mkdir "E:\vervestride\.gradle"
C:\flutter\bin\flutter.bat build apk --release --no-pub
