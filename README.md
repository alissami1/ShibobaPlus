# شيبوبة بلس

## البناء (Mac أو GitHub Actions)
    export THEOS=~/theos
    make package          # يطلع .deb ، والـ dylib داخل .theos/obj/ShibobaPlus.dylib

## الحقن بالـ IPA
    # الطريقة 1: Sideloadly -> Advanced Options -> Inject dylibs -> أضف ShibobaPlus.dylib
    # الطريقة 2: Azule
    azule -i Beegram_3_1.ipa -o out -f .theos/obj/ShibobaPlus.dylib
    # ثم أعد التوقيع (Sideloadly / AltStore)

## فتح الإعدادات
اضغط بثلاث أصابع لثانية بأي مكان بالتطبيق.

## ملاحظات
- لم يُبنَ ولم يُختبر على جهاز (ما عندي iOS SDK). أسماء الكلاسات تحققت منها من binary انستغرام 444.0.0.
- زيارات البروفايل: غير ممكنة، انستغرام ما يوفر هذي البيانات.
- إشعارات مشاهدة الستوري: تشتغل والتطبيق مفتوح أو بالخلفية القريبة، مو بعد ما iOS يقتله.

## البناء بدون ماك (GitHub Actions)
1. ارفع مجلد المشروع كامل (مع .github) على repo جديد بحسابك على GitHub.
2. تبويب Actions -> Build ShibobaPlus -> Run workflow.
3. بعد ما يخلص (دقيقتين تقريباً) نزّل Artifact باسم ShibobaPlus، فيه ShibobaPlus.dylib.
