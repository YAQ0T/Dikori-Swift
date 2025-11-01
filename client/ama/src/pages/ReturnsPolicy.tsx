// client/ama/src/pages/ReturnsPolicy.tsx
import React from "react";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";

const ReturnsPolicy: React.FC = () => {
  return (
    <>
      <Navbar />
      <main className="container mx-auto p-6 text-right" dir="rtl">
        <h1 className="text-3xl font-bold mb-4">سياسة الإرجاع والاستبدال</h1>
        <p className="text-gray-700 mb-6">
          نسعى في ديكوري لتقديم تجربة تسوّق موثوقة وسلسة. الرجاء قراءة سياسة
          الإرجاع والاستبدال التالية بعناية قبل إتمام عملية الشراء.
        </p>

        <section className="space-y-3 mb-6">
          <h2 className="text-xl font-semibold">شروط القبول</h2>
          <ul className="list-disc pr-5 space-y-2">
            <li>
              <strong>مشكلة من المصدر:</strong> في حال كان المنتج معيبًا أو
              تالفًا أو هناك خطأ منّا في التنفيذ/التجهيز،{" "}
              <strong>نقبل الإرجاع</strong> أو الاستبدال بدون أي رسوم إضافية.
            </li>
            <li>
              <strong>عدم مطابقة المنتج المطلوب:</strong> إذا كان المنتج المستلم{" "}
              <strong>لا يطابق المواصفات المطلوبة</strong> في الطلب
              (النوع/اللون/المقاس)، تتوفر <strong>آلية إرجاع</strong> أو استبدال
              وفقًا للحالة.
            </li>
            <li>
              <strong>استخدام أو فتح المنتج:</strong> في حال تم{" "}
              <strong>فتح المنتج أو استخدامه</strong> أو إزالة التغليف الأصلي
              غير القابل للإرجاع، <strong>لا يُقبل الإرجاع</strong> إلا في
              الحالات المصنعية المعيبة المثبتة.
            </li>
          </ul>
        </section>

        <section className="space-y-3 mb-6">
          <h2 className="text-xl font-semibold">الإطار الزمني</h2>
          <ul className="list-disc pr-5 space-y-2">
            <li>
              يجب إبلاغنا بطلب الإرجاع/الاستبدال خلال <strong>48 ساعة</strong>{" "}
              من استلام الطلب، مع إرفاق صور واضحة تبين المشكلة.
            </li>
            <li>
              يجب إعادة شحن المنتج خلال <strong>3 أيام عمل</strong> من موافقة
              فريق خدمة العملاء على الطلب.
            </li>
          </ul>
        </section>

        <section className="space-y-3 mb-6">
          <h2 className="text-xl font-semibold">حالة المنتج المرتجع</h2>
          <ul className="list-disc pr-5 space-y-2">
            <li>غير مستخدم (إلا في العيوب المصنعية المثبتة).</li>
            <li>بالعبوة الأصلية وبكامل الملحقات والفواتير إن وجدت.</li>
            <li>
              خالي من الروائح أو الآثار أو الأضرار الناتجة عن سوء الاستخدام.
            </li>
          </ul>
        </section>

        <section className="space-y-3 mb-6">
          <h2 className="text-xl font-semibold">الرسوم والتكاليف</h2>
          <ul className="list-disc pr-5 space-y-2">
            <li>
              في الحالات التي تكون <strong>المشكلة من المصدر</strong> أو{" "}
              <strong>عدم مطابقة المنتج</strong>، تتحمّل ديكوري تكاليف الشحن
              والإرجاع/الاستبدال.
            </li>
            <li>
              في الحالات الأخرى المقبولة (إن وُجدت)، قد يتحمّل المشتري رسوم
              الشحن/المناولة وفقًا لتقييم خدمة العملاء.
            </li>
          </ul>
        </section>

        <section className="space-y-3 mb-6">
          <h2 className="text-xl font-semibold">طريقة الإرجاع</h2>
          <ol className="list-decimal pr-5 space-y-2">
            <li>
              التواصل معنا خلال المدة المحددة عبر وسائل الاتصال المتاحة مع إرفاق{" "}
              <strong>رقم الطلب</strong> وشرح المشكلة وصور واضحة.
            </li>
            <li>
              يراجع فريقنا الطلب ويقيّم الحالة ويزوّدك بخيارات الاستبدال/الإرجاع
              وتفاصيل الشحن.
            </li>
            <li>
              بعد استلام المنتج وفحصه، يتم <strong>إرسال بديل</strong> أو{" "}
              <strong>إصدار رصيد/استرجاع</strong> بحسب ما يتم الاتفاق عليه.
            </li>
          </ol>
        </section>

        <section className="space-y-3 mb-6">
          <h2 className="text-xl font-semibold">استثناءات عامة</h2>
          <ul className="list-disc pr-5 space-y-2">
            <li>
              المنتجات المخصّصة/حسب الطلب قد لا تقبل الإرجاع إلا لعيب مصنعي.
            </li>
            <li>بطاقات الهدايا أو المنتجات القابلة للاستهلاك قد تُستثنى.</li>
            <li>أي تلاعب أو استعمال خاطئ يلغي أهلية الإرجاع.</li>
          </ul>
        </section>

        <p className="text-sm text-gray-600">
          تحتفظ ديكوري بالحق في تحديث هذه السياسة بما يتوافق مع القوانين
          والمعايير التجارية. آخر تحديث يتم نشره على هذه الصفحة.
        </p>
      </main>
      <Footer />
    </>
  );
};

export default ReturnsPolicy;
