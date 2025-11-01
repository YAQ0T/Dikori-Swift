// src/components/common/OfferDialog.tsx
import * as React from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";

interface OfferDialogProps {
  open: boolean;
  onClose: () => void;
}

const OfferDialog: React.FC<OfferDialogProps> = ({ open, onClose }) => {
  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-md bg-white text-black dark:bg-black dark:text-white rounded-2xl  border border-gray-200 dark:border-gray-800 min-h-[60vh] max-h-[90vh] flex flex-col">
        <DialogHeader>
          <DialogTitle className="text-xl font-bold text-center">
            🎉 عرض خاص لك!
          </DialogTitle>
        </DialogHeader>

        <div className="flex-1 flex flex-col items-center gap-4 overflow-hidden">
          <div className="w-full h-[90%] flex-1 rounded-lg overflow-hidden">
            <img
              src="https://i.imgur.com/kuiOKPC.png"
              alt="Offer"
              className="w-full h-full object-cover max-h-[60vh]"
            />
          </div>
          <p className="text-center text-sm opacity-80">
            خصم 30% على جميع المنتجات لفترة محدودة. لا تفوت الفرصة!
          </p>
          <Button
            onClick={onClose}
            className="w-full bg-black text-white hover:bg-gray-800 dark:bg-white dark:text-black dark:hover:bg-gray-200"
          >
            فهمت ✨
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default OfferDialog;
