// client/ama/src/lib/lahza.ts
import { loadScript } from "./loadScript";

declare global {
  interface Window {
    Lahza?: any; // مكتبة لَهْزة للبوب أب
  }
}

const LAHZA_JS_SRC = "https://js.lahza.io/v1/popup.js"; // أو inline.min.js حسب الدليل
const PUBLIC_KEY = import.meta.env.VITE_LAHZA_PUBLIC_KEY as string;

export async function openLahzaCheckout(opts: {
  amount: number; // أصغر وحدة (agora/cents)
  currency: "ILS" | "JOD" | "USD";
  email?: string;
  reference?: string;
  firstName?: string;
  lastName?: string;
  mobile?: string;
  metadata?: Record<string, any>;
  onSuccess?: (payload: any) => void;
  onCancel?: (payload: any) => void;
}) {
  if (!PUBLIC_KEY) throw new Error("VITE_LAHZA_PUBLIC_KEY is missing");
  await loadScript(LAHZA_JS_SRC);

  if (!window.Lahza) {
    throw new Error("Lahza JS not available. Check LAHZA_JS_SRC.");
  }

  // بعض إصدارات لَهْزة تستخدم LahzaPopup().newTransaction
  const LahzaPopup = (window as any).LahzaPopup;
  if (!LahzaPopup) {
    throw new Error("LahzaPopup is not available.");
  }
  const lahzaPopup = new LahzaPopup(); // Instantiate LahzaPopup directly here

  lahzaPopup.newTransaction?.({
    key: PUBLIC_KEY,
    amount: opts.amount,
    currency: opts.currency,
    email: opts.email,
    ref: opts.reference,
    mobile: opts.mobile,
    firstName: opts.firstName,
    lastName: opts.lastName,
    metadata: opts.metadata || {},
    onSuccess: (payload: any) => {
      opts.onSuccess?.(payload);
    },
    onCancel: (payload: any) => {
      opts.onCancel?.(payload);
    },
  });
}
