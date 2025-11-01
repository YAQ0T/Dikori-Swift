import React, { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { ShoppingCart } from "lucide-react";
import { useCart } from "@/context/CartContext";
import clsx from "clsx";
import { subscribeToCartHighlight } from "@/lib/cartHighlight";

const CartButton: React.FC = () => {
  const { cart } = useCart();
  const count = cart.reduce((sum, item) => sum + item.quantity, 0);
  const [highlight, setHighlight] = useState(false);
  const timeoutRef = useRef<number | null>(null);

  useEffect(() => {
    return subscribeToCartHighlight(() => {
      setHighlight(true);
      if (timeoutRef.current !== null) {
        window.clearTimeout(timeoutRef.current);
      }
      timeoutRef.current = window.setTimeout(() => {
        setHighlight(false);
      }, 800);
    });
  }, []);

  useEffect(() => {
    return () => {
      if (timeoutRef.current !== null) {
        window.clearTimeout(timeoutRef.current);
      }
    };
  }, []);

  return (
    <Link
      to="/cart"
      className={clsx(
        "relative inline-flex items-center justify-center transition-transform duration-200",
        highlight && "scale-110 text-amber-500 drop-shadow-[0_0_12px_rgba(251,191,36,0.45)]"
      )}
    >
      <ShoppingCart
        size={28}
        className={clsx(
          "transition-colors duration-200",
          highlight && "text-amber-500"
        )}
      />
      {count > 0 && (
        <span className="absolute -top-2 -right-2 bg-red-600 text-white rounded-full text-xs w-5 h-5 flex items-center justify-center">
          {count}
        </span>
      )}
    </Link>
  );
};

export default CartButton;
