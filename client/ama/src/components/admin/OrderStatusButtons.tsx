import React, { useMemo } from "react";
import { Button } from "@/components/ui/button";
import { useTranslation } from "@/i18n";

type OrderStatus =
  | "waiting_confirmation"
  | "pending"
  | "on_the_way"
  | "delivered"
  | "cancelled";

interface OrderStatusButtonsProps {
  orderId: string;
  updateStatus: (orderId: string, newStatus: OrderStatus) => Promise<void>;
}

const OrderStatusButtons: React.FC<OrderStatusButtonsProps> = ({
  orderId,
  updateStatus,
}) => {
  const { t } = useTranslation();
  const statusButtons = useMemo(
    () => [
      {
        status: "waiting_confirmation" as OrderStatus,
        variant: "outline" as const,
        label: t("admin.orderStatus.waiting_confirmation"),
      },
      {
        status: "on_the_way" as OrderStatus,
        variant: "outline" as const,
        label: t("admin.orderStatus.on_the_way"),
      },
      {
        status: "pending" as OrderStatus,
        variant: "outline" as const,
        label: t("admin.orderStatus.pending"),
      },
      {
        status: "cancelled" as OrderStatus,
        variant: "destructive" as const,
        label: t("admin.orderStatus.cancelled"),
        className: "me-2",
      },
      {
        status: "delivered" as OrderStatus,
        variant: "outline" as const,
        label: t("admin.orderStatus.delivered"),
      },
    ],
    [t]
  );

  return (
    <div className="space-x-4 space-x-reverse space-y-2">
      {statusButtons.map((button) => (
        <Button
          key={button.status}
          size="sm"
          onClick={() => updateStatus(orderId, button.status)}
          variant={button.variant}
          className={button.className}
        >
          {button.label}
        </Button>
      ))}
    </div>
  );
};

export default OrderStatusButtons;
