# flutter_local_notifications menyimpan jadwal notifikasi dengan Gson. Tanpa aturan ini, R8 membuang info tipe
# generik dan aplikasi berhenti ("VoKas has stopped") saat notifikasi terjadwal muncul di latar belakang.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.** { *; }

# google_sign_in / Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
