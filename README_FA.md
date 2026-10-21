# بازیافت من — پروژه موبایلی Flutter برای Android و iOS (نسخه ۰.۲)

این پروژه **کد واقعی اپلیکیشن موبایل بومی Flutter** است. فایل ZIP خودِ اپلیکیشن نصب‌شدنی نیست. Android خروجی APK و iOS پس از امضای اپل، خروجی قابل‌نصب/توزیع خواهد داشت. طراحی هر دو از یک کدبیس مشترک استفاده می‌کند.

## امکانات نسخه نمایشی
ثبت درخواست بازیافت، انتخاب مواد و مقدار، نشانی و نقشه OpenStreetMap، زمان‌بندی نمایشی، پیگیری نمایشی، کیف پول غیرواقعی و حافظه روی دستگاه. بدون سرور، SMS، پرداخت یا اعزام واقعی. برای نقشه به اینترنت نیاز است؛ آدرس را می‌توان دستی نوشت.

## خروجی APK اندروید — ساده‌ترین مسیر با GitHub Actions
۱. یک مخزن خصوصی GitHub بسازید و **محتوای داخل این پوشه** (نه خود پوشه مادر) را آپلود کنید؛ پوشه مخفی `.github` حتماً باید حفظ شود.
۲. به تب Actions در مخزن بروید و workflow «Build Android APK» را باز کنید (یا بعد از push منتظر اجرای خودکار باشید).
۳. پس از سبز شدن اجرای workflow، از قسمت Artifacts بسته `bazyaft-android-test-apk` را دانلود و unzip کنید.
۴. `app-debug.apk` را به گوشی اندرویدی منتقل و نصب کنید. این نسخه مخصوص آزمون است، برای توزیع عمومی و امنیت عملیاتی مناسب نیست.

## نسخه iPhone / iOS
* نیازی به بازنویسی کل برنامه نیست: Flutter کد مشترک دارد و فقط مرحله ساخت، امضا و انتشار مخصوص iOS است.
* پوشه `.github/workflows/ios-simulator.yml` یک **بررسی فنی iOS** روی macOS انجام می‌دهد: Actions → «Validate iOS Simulator Build» → Run workflow. فایل `Runner.app` خروجی فقط برای شبیه‌ساز توسعه است و **روی آیفون واقعی نصب نمی‌شود**.
* برای ساخت نسخه واقعی آیفون: macOS + Xcode و امضای معتبر Apple لازم است. برای تست خصوصی مستقیم با Mac ممکن است Apple Account رایگان کافی باشد (محدودیت‌های زمانی/دستگاهی دارد)؛ توزیع گسترده از طریق TestFlight یا App Store معمولاً عضویت Apple Developer Program و رعایت شرایط اپل را می‌خواهد.
* شناسه `ir.bazyaftdemo.bazyaft_mobile` موقت است. قبل از انتشار، نام و شناسه تجاری نهایی مشخص و تنظیم شوند؛ همچنین مجوزهای قانونی و دسترسی منطقه‌ای سرویس‌های توزیع بررسی شوند.
* تنها با ساخت IPA بدون امضا نمی‌توان برنامه را مثل APK روی هر آیفونی نصب کرد.

## ساخت روی دستگاه توسعه‌دهنده
### Android
```sh
flutter create --platforms=android --project-name bazyaft_mobile --org ir.bazyaftdemo .
flutter pub get
flutter build apk --debug
```
برای بارگذاری کاشی‌های نقشه در Android فایل `android/app/src/main/AndroidManifest.xml` باید مجوز `android.permission.INTERNET` را پیش از `<application>` داشته باشد (workflow GitHub آن را اضافه می‌کند).
### iOS (روی macOS)
```sh
flutter create --platforms=ios --project-name bazyaft_mobile --org ir.bazyaftdemo .
flutter pub get
flutter build ios --simulator
```
برای نصب روی آیفون واقعی باید Signing & Capabilities در Xcode تنظیم شود. خروجی آزمون شبیه‌ساز جای فایل نصب آیفون را نمی‌گیرد.

## وضعیت واقعی پروژه
این پروژه هنوز در ابزار ساخت Flutter/Android SDK کامپایل و تست نشده است. این محیط Flutter/Android SDK ندارد و به سرویس ساخت GitHub حساب کاربر هم دسترسی فعال نداشته؛ بنابراین فایل APK یا IPA آماده در این بسته موجود نیست. بعد از اجرای workflow باید خروجی و خطاها بررسی و اصلاح شوند.
