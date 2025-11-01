import React, { useState, useEffect, useRef } from "react";

interface QuantityInputProps {
  quantity: number;
  onChange: (newQty: number) => void;
  placeholder?: string;
  placeholderQuantity?: number;
}

const QuantityInput: React.FC<QuantityInputProps> = ({
  quantity,
  onChange,
  placeholder,
  placeholderQuantity,
}) => {
  const effectivePlaceholderQuantity = placeholderQuantity ?? 1;
  const hasPlaceholderConfig =
    placeholder !== undefined || placeholderQuantity !== undefined;

  const [tempValue, setTempValue] = useState<string>(quantity.toString());
  const [isDirty, setIsDirty] = useState<boolean>(false);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (document.activeElement !== inputRef.current) {
      setTempValue(quantity.toString());
      if (hasPlaceholderConfig) {
        setIsDirty(quantity !== effectivePlaceholderQuantity);
      }
    }
  }, [quantity, effectivePlaceholderQuantity, hasPlaceholderConfig]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value;

    // السماح فقط بالأرقام أو فراغ مؤقت
    if (/^\d*$/.test(val)) {
      setTempValue(val);
      if (hasPlaceholderConfig) {
        setIsDirty(val !== "");
      }
    }
  };

  const handleBlur = () => {
    if (tempValue === "") {
      if (hasPlaceholderConfig) {
        onChange(effectivePlaceholderQuantity);
        setTempValue(effectivePlaceholderQuantity.toString());
        setIsDirty(false);
      } else {
        setTempValue(quantity.toString());
      }
      return;
    }

    const parsed = parseInt(tempValue, 10);
    if (!isNaN(parsed) && parsed >= 1) {
      onChange(parsed);
      setTempValue(parsed.toString());
      if (hasPlaceholderConfig) {
        setIsDirty(parsed !== effectivePlaceholderQuantity);
      }
    } else {
      setTempValue(quantity.toString()); // إرجاع القيمة الأصلية إذا فشل الإدخال
      if (hasPlaceholderConfig) {
        setIsDirty(quantity !== effectivePlaceholderQuantity);
      }
    }
  };

  const resolvedPlaceholder = placeholder ?? "الكمية";
  const shouldShowPlaceholder =
    hasPlaceholderConfig && !isDirty && quantity === effectivePlaceholderQuantity;
  const displayValue = shouldShowPlaceholder ? "" : tempValue;

  return (
    <input
      ref={inputRef}
      type="text"
      inputMode="numeric"
      pattern="[0-9]*"
      className="border w-20 px-2 py-1 rounded text-center"
      value={displayValue}
      placeholder={resolvedPlaceholder}
      onChange={handleChange}
      onBlur={handleBlur}
    />
  );
};

export default QuantityInput;
