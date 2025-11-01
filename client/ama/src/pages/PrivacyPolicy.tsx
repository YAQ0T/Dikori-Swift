// client/ama/src/pages/PrivacyPolicy.tsx
import React from "react";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";

const PrivacyPolicy: React.FC = () => {
  return (
    <>
      <Navbar />
      <main className="container mx-auto p-6 text-right" dir="rtl">
        <h1 className="text-3xl font-bold mb-4">سياسة الخصوصية</h1>
        <p className="text-gray-700 mb-6">
          خصوصيتك مهمة لنا. في ديكوري، نلتزم بحماية بياناتك الشخصية واستخدامها
          فقط للأغراض الموضّحة أدناه.
        </p>

        <section className="space-y-3 mb-6">
          <h2 className="text-xl font-semibold">البيانات التي نجمعها</h2>
          <ul className="list-disc pr-5 space-y-1">
            <li>معلومات الحساب: الاسم، البريد الإلكتروني، رقم الهاتف.</li>
            <li>
              معلومات الطلب والشحن: العنوان والتفاصيل اللازمة لإتمام الطلب.
            </li>
            <li>
              بيانات الاستخدام: مثل الصفحات التي تزورها والمنتجات التي تتصفحها.
            </li>
          </ul>
        </section>

        <section className="space-y-3 mb-6">
          <h2 className="text-xl font-semibold">كيف نستخدم بياناتك</h2>
          <ul className="list-disc pr-5 space-y-1">
            <li>معالجة الطلبات والدفع والتسليم وخدمة العملاء.</li>
            <li>تحسين تجربة التسوق وتخصيص العروض.</li>
            <li>
              الأمان ومنع الاحتيال، بما في ذلك استخدام خدمات مثل{" "}
              <strong>Google reCAPTCHA</strong> للتحقق ومنع النشاطات الضارة.
            </li>
          </ul>
        </section>

        <section className="space-y-3 mb-6">
          <h2 className="text-xl font-semibold">مشاركة البيانات</h2>
          <p className="text-gray-700">
            قد نشارك بعض البيانات مع مزوّدي الخدمات (بوابة الدفع/شركة
            الشحن/أنظمة التحليلات) بالقدر اللازم لتقديم الخدمة. لا نبيع بياناتك
            لطرف ثالث.
          </p>
        </section>

        <section className="space-y-3 mb-6">
          <h2 className="text-xl font-semibold">حقوقك</h2>
          <ul className="list-disc pr-5 space-y-1">
            <li>
              طلب الوصول لبياناتك أو تصحيحها أو حذفها ضمن الحدود القانونية.
            </li>
            <li>الانسحاب من الرسائل التسويقية في أي وقت.</li>
          </ul>
        </section>

        <section className="space-y-3 mb-6">
          <h2 className="text-xl font-semibold">التغييرات على السياسة</h2>
          <p className="text-gray-700">
            قد نقوم بتحديث هذه السياسة من وقت لآخر. سيتم نشر أي تعديل على هذه
            الصفحة.
          </p>
        </section>

        <section className="space-y-1 mb-6">
          <h2 className="text-xl font-semibold">تواصل معنا</h2>
          <p className="text-gray-700">
            لأي استفسار حول الخصوصية، الرجاء التواصل عبر صفحة{" "}
            <a href="/contact" className="text-blue-600 underline">
              اتصل بنا
            </a>
            .
          </p>
        </section>
      </main>
      <Footer />
    </>
  );
};

export default PrivacyPolicy;
