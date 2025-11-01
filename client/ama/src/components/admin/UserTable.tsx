import React from "react";
import { Button } from "@/components/ui/button";
import { useTranslation } from "@/i18n";

interface UserTableProps {
  users: any[];
  onDelete: (userId: string, userName: string) => void;
  currentAdminId: string; // لمنع حذف نفسه
}

const UserTable: React.FC<UserTableProps> = ({
  users,
  onDelete,
  currentAdminId,
}) => {
  const { t } = useTranslation();
  if (!users || users.length === 0) {
    return <p className="text-gray-600">{t("admin.users.empty")}</p>;
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-right border">
        <thead className="bg-gray-100">
          <tr>
            <th className="border px-4 py-2">#</th>
            <th className="border px-4 py-2">{t("common.labels.name")}</th>
            <th className="border px-4 py-2">{t("common.labels.email")}</th>
            <th className="border px-4 py-2">{t("common.labels.phone")}</th>
            <th className="border px-4 py-2">{t("admin.users.role")}</th>
            <th className="border px-4 py-2">{t("common.labels.actions")}</th>
          </tr>
        </thead>
        <tbody>
          {users.map((user, idx) => (
            <tr key={user._id}>
              <td className="border px-4 py-2">{idx + 1}</td>
              <td className="border px-4 py-2">{user.name}</td>
              <td className="border px-4 py-2">{user.email}</td>
              <td className="border px-4 py-2">{user.phone || "-"}</td>
              <td className="border px-4 py-2">
                {user.role === "admin"
                  ? t("admin.users.roles.admin")
                  : user.role === "dealer"
                  ? t("admin.users.roles.dealer")
                  : t("admin.users.roles.customer")}
              </td>
              <td className="border px-4 py-2">
                {user._id !== currentAdminId && (
                  <Button
                    variant="destructive"
                    size="sm"
                    onClick={() => onDelete(user._id, user.name)}
                  >
                    {t("common.actions.delete")}
                  </Button>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default UserTable;
