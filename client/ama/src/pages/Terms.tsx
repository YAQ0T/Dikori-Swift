import React from "react";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";

const Terms: React.FC = () => {
  return (
    <>
      <Navbar />
      <main className="container mx-auto p-6 text-right space-y-4">
        <h1 className="text-3xl font-bold mb-4">شروط الاستخدام</h1>
        <p>
          باستخدامك لموقع ديكوري, فإنك توافق على الالتزام بشروط الاستخدام
          التالية.
        </p>
        <p>
          يُمنع استخدام الموقع لأي غرض غير قانوني أو مسيء. نحن نحتفظ بحقنا في
          تعديل أو إيقاف الموقع أو أي خدمة في أي وقت دون إشعار.
        </p>
        <p>
          نحن غير مسؤولين عن أي خسارة قد تنتج عن استخدامك للموقع. يرجى مراجعة
          هذه الصفحة دوريًا لمعرفة التحديثات.
        </p>
      </main>
      <Footer />
    </>
  );
};

export default Terms;
