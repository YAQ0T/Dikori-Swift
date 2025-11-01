// src/components/common/OfferBanner.tsx
import React from "react";
import { X } from "lucide-react";

const OfferBanner: React.FC<{ message: string; onClose?: () => void }> = ({
  message,
  onClose,
}) => {
  return (
    <div className="bg-gradient-to-r from-pink-500 to-red-500 text-white text-center p-2 flex items-center justify-between">
      <span className="mx-auto font-semibold">{message}</span>
      {onClose && (
        <button onClick={onClose} className="mr-4">
          <X size={20} />
        </button>
      )}
    </div>
  );
};

export default OfferBanner;
