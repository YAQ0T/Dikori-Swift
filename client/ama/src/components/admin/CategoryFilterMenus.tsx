// src/components/admin/CategoryFilterMenus.tsx
import React from "react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useTranslation } from "@/i18n";

interface CategoryFilterMenusProps {
  selectedMainCategory: string;
  setSelectedMainCategory: (value: string) => void;
  productFilter: string;
  setProductFilter: (value: string) => void;
  categoryMap: Record<string, Set<string>>;

  // ✅ جديد: تصفية نوع الملكية
  ownershipFilter: "all" | "ours" | "local";
  setOwnershipFilter: (value: "all" | "ours" | "local") => void;
}

const CategoryFilterMenus: React.FC<CategoryFilterMenusProps> = ({
  selectedMainCategory,
  setSelectedMainCategory,
  setProductFilter,
  categoryMap,
  ownershipFilter,
  setOwnershipFilter,
}) => {
  const { t } = useTranslation();

  const ownershipLabel = t(
    `admin.categoryFilters.ownership.options.${ownershipFilter}` as const
  );

  const allLabel = t("common.all");

  return (
    <div className="flex flex-wrap gap-2">
      {/* 🔽 تصفية حسب نوع الملكية */}
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="outline">
            {t("admin.categoryFilters.ownership.label", {
              label: ownershipLabel,
            })}
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={() => setOwnershipFilter("all")}>
            {allLabel}
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => setOwnershipFilter("ours")}>
            {t("admin.categoryFilters.ownership.options.ours")}
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => setOwnershipFilter("local")}>
            {t("admin.categoryFilters.ownership.options.local")}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      {/* 🔽 تصفية حسب التصنيف الفرعي */}
      {selectedMainCategory !== "all" && (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="outline">
              {t("admin.categoryFilters.subFilter")}
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            {Array.from(categoryMap[selectedMainCategory] || []).map((sub) => (
              <DropdownMenuItem
                key={String(sub)}
                onClick={() => setProductFilter(sub as string)}
              >
                {String(sub)}
              </DropdownMenuItem>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>
      )}

      {/* 🔽 تصفية حسب التصنيف الرئيسي */}
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="outline">
            {t("admin.categoryFilters.mainFilter")}
            {selectedMainCategory !== "all"
              ? `: ${String(selectedMainCategory)}`
              : ""}
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem
            onClick={() => {
              setSelectedMainCategory("all");
              setProductFilter("all");
            }}
          >
            {allLabel}
          </DropdownMenuItem>

          {Object.keys(categoryMap).map((main) => (
            <DropdownMenuItem
              key={main}
              onClick={() => {
                setSelectedMainCategory(main);
                setProductFilter(main);
              }}
            >
              {main}
            </DropdownMenuItem>
          ))}
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
};

export default CategoryFilterMenus;
