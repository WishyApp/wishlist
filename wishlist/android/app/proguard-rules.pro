# Préserver les annotations J2ObjC utilisées par Guava
-dontwarn com.google.j2objc.**
-keep class com.google.j2objc.** { *; }
# image_cropper (uCrop) : OkHttp n'est utilisé que pour charger une image
# distante, une option que l'app n'utilise pas, et la dépendance n'est pas
# embarquée. Sans ces règles, R8 échoue sur les classes okhttp3 manquantes.
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class com.yalantis.ucrop** { *; }
-keep interface com.yalantis.ucrop** { *; }
