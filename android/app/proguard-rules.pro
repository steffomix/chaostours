# https://github.com/builttoroam/device_calendar/issues/99#issuecomment-612449677
#Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# You might not be using firebase
# -keep class com.google.firebase.** { *; }
-keep class com.builttoroam.devicecalendar.** { *; }