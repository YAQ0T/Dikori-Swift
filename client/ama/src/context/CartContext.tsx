// 🧠 CartContext.tsx
import { createContext, useContext, useEffect, useState } from "react";
import type { ReactNode } from "react";
import type { LocalizedText } from "@/lib/localized";

export type Product = {
  _id: string;
  name: LocalizedText;
  price: number;
  image: string;
  selectedColor?: string; // ✅ اللون المختار
  selectedMeasure?: string; // ✅ المقاس المختار
};

type CartItem = Product & { quantity: number };

type CartContextType = {
  cart: CartItem[];
  addToCart: (product: Product, quantity?: number) => void;
  removeFromCart: (
    productId: string,
    selectedColor?: string,
    selectedMeasure?: string
  ) => void;
  clearCart: () => void;
  updateQuantity: (
    productId: string,
    quantity: number,
    selectedColor?: string,
    selectedMeasure?: string
  ) => void;
};

const CartContext = createContext<CartContextType | null>(null);

// مفتاح التخزين المحلي
const STORAGE_KEY = "madina_cart_v1";

export const CartProvider = ({ children }: { children: ReactNode }) => {
  // ✅ تحميل أولي من localStorage (Lazy initializer)
  const [cart, setCart] = useState<CartItem[]>(() => {
    try {
      const raw =
        typeof window !== "undefined"
          ? localStorage.getItem(STORAGE_KEY)
          : null;
      return raw ? (JSON.parse(raw) as CartItem[]) : [];
    } catch {
      return [];
    }
  });

  // ✅ حفظ أي تغيير في السلة إلى localStorage
  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(cart));
    } catch {
      // ممكن تفشل إذا امتلأ التخزين أو في وضع خاص بالمتصفح
    }
  }, [cart]);

  // ✅ تزامن بين التبويبات (لو فاتح الموقع بأكثر من تبويب)
  useEffect(() => {
    const onStorage = (e: StorageEvent) => {
      if (e.key === STORAGE_KEY && e.newValue) {
        try {
          const next = JSON.parse(e.newValue) as CartItem[];
          setCart(next);
        } catch {
          // تجاهل
        }
      }
    };
    window.addEventListener("storage", onStorage);
    return () => window.removeEventListener("storage", onStorage);
  }, []);

  const addToCart = (product: Product, quantity = 1) => {
    setCart((prev) => {
      const clampedQuantity = Math.max(1, quantity);
      const existing = prev.find(
        (item) =>
          item._id === product._id &&
          item.selectedColor === product.selectedColor &&
          item.selectedMeasure === product.selectedMeasure
      );

      if (existing) {
        return prev.map((item) =>
          item._id === product._id &&
          item.selectedColor === product.selectedColor &&
          item.selectedMeasure === product.selectedMeasure
            ? { ...item, quantity: item.quantity + clampedQuantity }
            : item
        );
      }

      // تأكد من وجود quantity 初 مرة
      return [...prev, { ...product, quantity: clampedQuantity }];
    });
  };

  const removeFromCart = (
    productId: string,
    selectedColor?: string,
    selectedMeasure?: string
  ) => {
    setCart((prev) =>
      prev.filter(
        (item) =>
          !(
            item._id === productId &&
            item.selectedColor === selectedColor &&
            item.selectedMeasure === selectedMeasure
          )
      )
    );
  };

  const clearCart = () => {
    setCart([]);
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch {
      // تجاهل
    }
  };

  const updateQuantity = (
    productId: string,
    quantity: number,
    selectedColor?: string,
    selectedMeasure?: string
  ) => {
    setCart((prev) => {
      if (quantity <= 0) {
        // إذا وصل الصفر احذف العنصر
        return prev.filter(
          (item) =>
            !(
              item._id === productId &&
              item.selectedColor === selectedColor &&
              item.selectedMeasure === selectedMeasure
            )
        );
      }

      return prev.map((item) =>
        item._id === productId &&
        item.selectedColor === selectedColor &&
        item.selectedMeasure === selectedMeasure
          ? { ...item, quantity }
          : item
      );
    });
  };

  return (
    <CartContext.Provider
      value={{ cart, addToCart, removeFromCart, clearCart, updateQuantity }}
    >
      {children}
    </CartContext.Provider>
  );
};

export const useCart = () => {
  const ctx = useContext(CartContext);
  if (!ctx) {
    throw new Error("useCart must be used within a CartProvider");
  }
  return ctx;
};
