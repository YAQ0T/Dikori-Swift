// client/ama/src/components/PayWithLahza.tsx
import { useState } from "react";
import { openLahzaCheckout } from "../lib/lahza";

function makeRef(prefix = "ORD") {
  const rand = Math.random().toString(36).slice(2, 8).toUpperCase();
  const ts = Date.now().toString(36).toUpperCase();
  return `${prefix}_${ts}_${rand}`;
}

type Props = {
  amount: number; // المبلغ (حسب وحدة Lahza)
  currency?: "ILS" | "JOD" | "USD";
  email?: string;
  name?: string;
  phone?: string;
  metadata?: Record<string, any>;
  buttonText?: string;
};

export default function PayWithLahza({
  amount,
  currency = "ILS",
  email,
  metadata,
  buttonText = "ادفع الآن",
}: Props) {
  const [loading, setLoading] = useState(false);
  const [reference] = useState(makeRef("ORD"));

  async function handlePay() {
    try {
      setLoading(true);

      await openLahzaCheckout({
        amount,
        currency,
        email,
        reference,
        metadata,
        onSuccess: async () => {
          // بعد نجاح الواجهة، نسأل السيرفر للتأكيد النهائي
          try {
            const base = import.meta.env.PROD
              ? "" // نفس الدومين (dikori.com) — عدّل إذا عندك دومين API منفصل
              : "http://localhost:3001";
            const resp = await fetch(
              `${base}/api/payments/status/${reference}`
            );
            const json = await resp.json();

            const status = json?.data?.status; // success / failed / ...
            if (status === "success") {
              alert("تم الدفع بنجاح ✅");
              // TODO: ممكن توجه المستخدم لصفحة الطلب / الحساب
            } else {
              alert("فشل تأكيد الدفع من السيرفر ❌");
            }
          } catch (e) {
            console.error(e);
            alert("تعذر جلب حالة الدفع من السيرفر");
          } finally {
            setLoading(false);
          }
        },
        onCancel: () => {
          setLoading(false);
          alert("تم إلغاء عملية الدفع");
        },
      });
    } catch (e: any) {
      console.error(e);
      alert(e?.message || "تعذر فتح بوابة الدفع");
      setLoading(false);
    }
  }

  return (
    <button
      onClick={handlePay}
      disabled={loading}
      style={{
        padding: "12px 18px",
        borderRadius: 10,
        border: "none",
        fontWeight: 600,
        cursor: "pointer",
        opacity: loading ? 0.6 : 1,
      }}
    >
      {loading ? "جارٍ المعالجة..." : buttonText}
    </button>
  );
}
