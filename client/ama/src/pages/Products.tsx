// src/pages/Products.tsx
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { Input } from "@/components/ui/input";
import ProductCard from "@/components/ProductCard";
import CategoryCircles from "@/components/CategoryCircles";
import { useLocation, useNavigate } from "react-router-dom";
import axios from "axios";
import { useAuth } from "@/context/AuthContext";
import {
  getLocalizedText,
  ensureLocalizedObject,
  type LocalizedText,
} from "@/lib/localized";
import { getColorLabel } from "@/lib/colors";
import { useLanguage } from "@/context/LanguageContext";
import { useTranslation } from "@/i18n";

import {
  Pagination,
  PaginationContent,
  PaginationItem,
  PaginationLink,
  PaginationNext,
  PaginationPrevious,
  PaginationEllipsis,
} from "@/components/ui/pagination";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

type ProductItem = {
  _id: string;
  name: LocalizedText;
  description: LocalizedText;
  images: string[];
  mainCategory?: string;
  subCategory?: string;
  minPrice?: number;
  totalStock?: number;
  price: number;
  quantity: number;
};

type FacetItem = { name: string; slug: string };
type Facets = { measures: FacetItem[]; colors: FacetItem[] };
type OwnershipFilter = "all" | "ours" | "local";
type CategoryGroup = { mainCategory: string; subCategories: string[] };

const PAGE_WINDOW = 5;

/** ✅ دالة مساعدة: ما بتضيف ? إلا إذا فيه باراميترات */
function withQuery(base: string, params: URLSearchParams) {
  const qs = params.toString();
  return qs ? `${base}?${qs}` : base;
}

function buildPageWindow(
  current: number,
  total: number,
  windowSize: number = PAGE_WINDOW
): (number | "ellipsis")[] {
  if (total <= windowSize) {
    return Array.from({ length: total }, (_, i) => i + 1);
  }
  const pages: (number | "ellipsis")[] = [];
  const first = 1;
  const last = total;
  const half = Math.floor(windowSize / 2);
  let start = Math.max(first, current - half);
  let end = Math.min(last, start + windowSize - 1);
  if (end - start + 1 < windowSize)
    start = Math.max(first, end - windowSize + 1);
  if (start > first) {
    pages.push(first);
    if (start > first + 1) pages.push("ellipsis");
  }
  for (let p = start; p <= end; p++) pages.push(p);
  if (end < last) {
    if (end < last - 1) pages.push("ellipsis");
    pages.push(last);
  }
  return pages;
}

function slugifyLabel(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "-")
    .replace(/[^\p{L}\p{N}-]+/gu, "");
}

const Products: React.FC = () => {
  const { user, token } = useAuth();
  const canUseOwnership = user?.role === "admin" || user?.role === "dealer";
  const { locale } = useLanguage();

  const { t } = useTranslation();

  const location = useLocation();

  const [selectedMainCategory, setSelectedMainCategory] = useState<string>(
    () => {
      return new URLSearchParams(location.search).get("category") ?? "";
    }
  );
  const [selectedSubCategory, setSelectedSubCategory] = useState(() => {
    return new URLSearchParams(location.search).get("sub") ?? "";
  });

  const [rawSearch, setRawSearch] = useState("");
  const [searchTerm, setSearchTerm] = useState("");

  const [rawMaxPrice, setRawMaxPrice] = useState("");
  const [maxPrice, setMaxPrice] = useState("");

  const [selectedColorSlug, setSelectedColorSlug] = useState("");
  const [selectedMeasureSlug, setSelectedMeasureSlug] = useState("");

  const [ownershipFilter, setOwnershipFilter] =
    useState<OwnershipFilter>("all");

  const [products, setProducts] = useState<ProductItem[]>([]);
  const [totalPages, setTotalPages] = useState(1);
  const [loading, setLoading] = useState(true);

  const [facets, setFacets] = useState<Facets>({ measures: [], colors: [] });
  const [loadingFacets, setLoadingFacets] = useState(false);
  const [facetsError, setFacetsError] = useState<string | null>(null);

  const navigate = useNavigate();
  const [currentPage, setCurrentPage] = useState(1);

  const [recentDays, setRecentDays] = useState<number | null>(null);
  const [recentTotal, setRecentTotal] = useState<number | null>(null);

  const [categoryMenu, setCategoryMenu] = useState<CategoryGroup[]>([]);
  const [loadingCategories, setLoadingCategories] = useState<boolean>(false);

  // 👇 جديد: خريطة صور الفروع من البيانات (تلقائيًا)
  const [subCategoryImagesFromData, setSubCategoryImagesFromData] = useState<
    Record<string, string>
  >({});

  const [suggestions, setSuggestions] = useState<string[]>([]);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [highlightIndex, setHighlightIndex] = useState<number>(-1);

  const translateCategoryLabel = useCallback(
    (value: string, type: "main" | "sub") => {
      if (!value) return value;
      const slug = slugifyLabel(value);
      if (!slug) return value;
      return t(`productsPage.categoryLabels.${type}.${slug}`, {
        defaultValue: value,
      });
    },
    [t]
  );

  const searchRef = useRef<HTMLInputElement | null>(null);
  const searchBoxWrapperRef = useRef<HTMLDivElement | null>(null);
  const maxPriceRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    setCurrentPage(1);
    searchRef.current?.focus();
  }, [searchTerm]);

  useEffect(() => {
    if (!canUseOwnership && ownershipFilter !== "all") {
      setOwnershipFilter("all");
    }
  }, [canUseOwnership, ownershipFilter]);

  useEffect(() => {
    const params = new URLSearchParams(location.search);
    const category = params.get("category") ?? "";
    const sub = params.get("sub") ?? "";

    setSelectedMainCategory((prev) => (prev === category ? prev : category));
    setSelectedSubCategory((prev) => (prev === sub ? prev : sub));
  }, [location.search]);

  useEffect(() => {
    const params = new URLSearchParams(location.search);
    if (selectedMainCategory) {
      params.set("category", selectedMainCategory);
    } else {
      params.delete("category");
    }
    if (selectedSubCategory) {
      params.set("sub", selectedSubCategory);
    } else {
      params.delete("sub");
    }
    const next = `?${params.toString()}`;
    if (next !== location.search) {
      navigate({ search: next }, { replace: true });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedMainCategory, selectedSubCategory]);

  // ✅ Scroll لأعلى عند تغيير الصفحة
  useEffect(() => {
    if (typeof window !== "undefined") {
      window.scrollTo({ top: 0, behavior: "smooth" });
    }
  }, [currentPage]);

  // Facets
  // ⬇️ أضف أعلى الملف مع بقية الـuseState
  // const [loadingFacets, setLoadingFacets] = useState(false);
  // const [facetsError, setFacetsError] = useState<string | null>(null);

  // Facets

  // Facets
  useEffect(() => {
    let ignore = false;
    (async () => {
      setLoadingFacets(true);
      setFacetsError(null);
      try {
        const params = new URLSearchParams();

        if (selectedMainCategory) {
          params.set("mainCategory", selectedMainCategory);
        }
        if (selectedSubCategory) params.set("subCategory", selectedSubCategory);
        if (searchTerm) params.set("q", searchTerm);
        if (canUseOwnership && ownershipFilter !== "all") {
          params.set("ownership", ownershipFilter);
        }
        // (اختياري) لو بدك يقيدها بأيام التحديث:
        // if (recentDays && recentDays > 0) params.set("days", String(recentDays));

        const base = `${import.meta.env.VITE_API_URL}/api/products/facets`;
        const url = withQuery(base, params);
        const headers = token
          ? { Authorization: `Bearer ${token}` }
          : undefined;

        const { data } = await axios.get(url, { headers });
        if (ignore) return;

        const f: Facets = {
          measures: Array.isArray(data?.measures)
            ? data.measures.filter((m: any) => m?.slug && m?.name)
            : [],
          colors: Array.isArray(data?.colors)
            ? data.colors.filter((c: any) => c?.slug && c?.name)
            : [],
        };
        setFacets(f);

        if (
          f.colors.length &&
          !f.colors.some((c) => c.slug === selectedColorSlug)
        ) {
          setSelectedColorSlug("");
        }
        if (
          f.measures.length &&
          !f.measures.some((m) => m.slug === selectedMeasureSlug)
        ) {
          setSelectedMeasureSlug("");
        }
      } catch (e) {
        setFacetsError(t("productsPage.facets.error"));
        setFacets({ measures: [], colors: [] });
      } finally {
        setLoadingFacets(false);
      }
    })();

    return () => {
      ignore = true;
    };
  }, [
    selectedMainCategory,
    selectedSubCategory,
    searchTerm,
    ownershipFilter,
    canUseOwnership,
    token,
    // recentDays, // إذا فعّلتها فوق أضِفها هنا أيضاً
    selectedColorSlug,
    selectedMeasureSlug,
    t,
  ]);

  // المنتجات
  useEffect(() => {
    let ignore = false;
    (async () => {
      setLoading(true);
      const params = new URLSearchParams();
      params.set("page", String(currentPage));
      params.set("limit", "9");
      if (selectedMainCategory) {
        params.set("mainCategory", selectedMainCategory);
      }
      if (selectedSubCategory) params.set("subCategory", selectedSubCategory);
      if (searchTerm) params.set("q", searchTerm);
      if (maxPrice) params.set("maxPrice", maxPrice);
      if (canUseOwnership && ownershipFilter !== "all") {
        params.set("ownership", ownershipFilter);
      }
      const tags: string[] = [];
      if (selectedColorSlug) tags.push(`color:${selectedColorSlug}`);
      if (selectedMeasureSlug) tags.push(`measure:${selectedMeasureSlug}`);
      if (tags.length) params.set("tags", tags.join(","));
      if (recentDays && recentDays > 0) {
        params.set("days", String(recentDays));
      }

      try {
        const base = `${import.meta.env.VITE_API_URL}/api/products`;
        const endpoint =
          recentDays && recentDays > 0
            ? `${base}/recent-updates`
            : `${base}/with-stats`;
        const url = withQuery(endpoint, params);

        const headers = token
          ? { Authorization: `Bearer ${token}` }
          : undefined;
        const res = await axios.get(url, { headers });
        if (ignore) return;

        const {
          items,
          totalPages: tp,
          total,
        } = res.data || {
          items: [],
          totalPages: 1,
          total: 0,
        };

        const mapped: ProductItem[] = (items || []).map((p: any) => ({
          _id: p._id,
          name: ensureLocalizedObject(p.name),
          description: ensureLocalizedObject(p.description),
          images: Array.isArray(p.images) ? p.images : [],
          mainCategory: p.mainCategory,
          subCategory: p.subCategory,
          minPrice: p.minPrice,
          totalStock: p.totalStock,
          price: typeof p.minPrice === "number" ? p.minPrice : 0,
          quantity: typeof p.totalStock === "number" ? p.totalStock : 0,
        }));

        setProducts(mapped);
        setTotalPages(tp || 1);

        // 👇 دمج صور الفروع من المنتجات المعروضة حالياً (لو في فرع بدون صورة محفوظة)
        setSubCategoryImagesFromData((prev) => {
          const next = { ...prev };
          for (const p of mapped) {
            if (!p?.mainCategory || !p?.subCategory) continue;
            const key = `${p.mainCategory}:::${p.subCategory}`;
            if (!next[key]) {
              const img =
                Array.isArray(p.images) && p.images[0] ? p.images[0] : "";
              if (img) next[key] = img;
            }
          }
          return next;
        });

        if (recentDays && recentDays > 0) {
          setRecentTotal(typeof total === "number" ? total : mapped.length);
        } else {
          setRecentTotal(null);
        }
      } catch {
        setTotalPages(1);
        if (recentDays && recentDays > 0) setRecentTotal(null);
      } finally {
        setLoading(false);
      }
    })();
    return () => {
      ignore = true;
    };
  }, [
    currentPage,
    selectedMainCategory,
    selectedSubCategory,
    searchTerm,
    maxPrice,
    selectedColorSlug,
    selectedMeasureSlug,
    ownershipFilter,
    canUseOwnership,
    token,
    recentDays,
  ]);

  // جلب شجرة التصنيفات + بناء صور فرعية تمثيلية من أول منتج يظهر لكل فرع
  useEffect(() => {
    let ignore = false;
    (async () => {
      setLoadingCategories(true);
      try {
        const headers = token
          ? { Authorization: `Bearer ${token}` }
          : undefined;
        const base = `${import.meta.env.VITE_API_URL}/api/products`;

        const PER_PAGE = 100;
        const firstParams = new URLSearchParams();
        firstParams.set("page", "1");
        firstParams.set("limit", String(PER_PAGE));

        const firstUrl = `${base}/with-stats?${firstParams.toString()}`;
        const firstRes = await axios.get(firstUrl, { headers });
        if (ignore) return;

        const firstData = firstRes.data || { items: [], totalPages: 1 };
        const totalPagesAll = Math.max(1, Number(firstData.totalPages) || 1);

        const map = new Map<string, Set<string>>();
        // 👇 خريطة صور الفروع من كامل البيانات (أول صورة لأول منتج يصادفنا)
        const subImg = new Map<string, string>();

        const consume = (items: any[]) => {
          for (const p of items || []) {
            const main = p?.mainCategory;
            const sub = p?.subCategory;
            if (!main) continue;

            // بناء شجرة التصنيفات
            if (!map.has(main)) map.set(main, new Set<string>());
            if (sub) map.get(main)!.add(sub);

            // بناء صورة الفرع
            if (sub) {
              const key = `${main}:::${sub}`;
              if (!subImg.has(key)) {
                const img =
                  Array.isArray(p?.images) && p.images[0] ? p.images[0] : "";
                if (img) subImg.set(key, img);
              }
            }
          }
        };

        consume(firstData.items || []);

        const MAX_PAGES = 20;
        const pagesToFetch = Math.min(totalPagesAll, MAX_PAGES);

        const requests: Promise<any>[] = [];
        for (let page = 2; page <= pagesToFetch; page++) {
          const params = new URLSearchParams();
          params.set("page", String(page));
          params.set("limit", String(PER_PAGE));
          const url = `${base}/with-stats?${params.toString()}`;
          requests.push(
            axios
              .get(url, { headers })
              .then((res) => res.data)
              .catch(() => null)
          );
        }

        const pages = await Promise.all(requests);
        if (ignore) return;

        for (const pageData of pages) {
          if (!pageData?.items) continue;
          consume(pageData.items);
        }

        const groups: CategoryGroup[] = Array.from(map.entries()).map(
          ([main, subs]) => ({
            mainCategory: main,
            subCategories: Array.from(subs.values()),
          })
        );

        groups.sort((a, b) =>
          a.mainCategory.localeCompare(b.mainCategory, "ar")
        );
        groups.forEach((g) =>
          g.subCategories.sort((a, b) => a.localeCompare(b, "ar"))
        );

        setCategoryMenu(groups);

        // حفظ صور الفروع المُستخلَصة
        setSubCategoryImagesFromData((prev) => {
          const merged = { ...prev };
          for (const [k, v] of subImg.entries()) {
            if (!merged[k]) merged[k] = v;
          }
          return merged;
        });
      } catch {
        // تجاهل الخطأ للحفاظ على القائمة الحالية
      } finally {
        setLoadingCategories(false);
      }
    })();

    return () => {
      ignore = true;
    };
  }, [token]);

  // اقتراحات البحث
  useEffect(() => {
    let active = true;
    if (!rawSearch.trim()) {
      setSuggestions([]);
      return;
    }

    const t = setTimeout(async () => {
      try {
        const headers = token
          ? { Authorization: `Bearer ${token}` }
          : undefined;
        const params = new URLSearchParams();
        params.set("page", "1");
        params.set("limit", "10");
        params.set("q", rawSearch.trim());

        const base = `${import.meta.env.VITE_API_URL}/api/products/with-stats`;
        const url = withQuery(base, params);

        const res = await axios.get(url, { headers });
        if (!active) return;

        const names = Array.from(
          new Set(
            (res.data?.items || [])
              .map((p: any) => getLocalizedText(p?.name, locale))
              .filter(
                (n: string | undefined) => typeof n === "string" && n.trim()
              )
          )
        ) as string[];

        setSuggestions(names.slice(0, 10));
      } catch {
        if (!active) return;
        setSuggestions([]);
      }
    }, 250);

    return () => {
      active = false;
      clearTimeout(t);
    };
  }, [rawSearch, token, locale]);

  useEffect(() => {
    const onDocClick = (e: MouseEvent) => {
      if (!searchBoxWrapperRef.current) return;
      if (!searchBoxWrapperRef.current.contains(e.target as Node)) {
        setShowSuggestions(false);
        setHighlightIndex(-1);
      }
    };
    document.addEventListener("mousedown", onDocClick);
    return () => document.removeEventListener("mousedown", onDocClick);
  }, []);

  const handleCategorySelect = (main: string, sub: string = "") => {
    if (main === selectedMainCategory && sub === selectedSubCategory) return;
    setSelectedMainCategory(main);
    setSelectedSubCategory(sub);
    setCurrentPage(1);
  };

  const categoryGroups = useMemo(() => {
    return products.reduce((acc, product) => {
      const { mainCategory, subCategory, images } = product;
      if (!mainCategory) return acc;

      const existing = acc.find(
        (cat: { mainCategory: string; subCategories: string[] }) =>
          cat.mainCategory === mainCategory
      );
      if (existing) {
        if (subCategory && !existing.subCategories.includes(subCategory)) {
          existing.subCategories.push(subCategory);
        }
      } else {
        acc.push({
          mainCategory,
          subCategories: subCategory ? [subCategory] : [],
        });
      }

      // 👇 تعزيز صور الفروع أيضًا من المنتجات الحالية
      if (mainCategory && subCategory) {
        const key = `${mainCategory}:::${subCategory}`;
        if (!subCategoryImagesFromData[key]) {
          const img = Array.isArray(images) && images[0] ? images[0] : "";
          if (img) {
            setSubCategoryImagesFromData((prev) => ({
              ...prev,
              [key]: img,
            }));
          }
        }
      }

      return acc;
    }, [] as { mainCategory: string; subCategories: string[] }[]);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [products]);

  const triggerSearch = () => {
    setSearchTerm(rawSearch.trim());
    setShowSuggestions(false);
    setHighlightIndex(-1);
  };

  const triggerMaxPrice = () => {
    const v = rawMaxPrice.trim();
    setMaxPrice(v);
    setCurrentPage(1);
    maxPriceRef.current?.focus();
  };

  const handleSearchKeyDown: React.KeyboardEventHandler<HTMLInputElement> = (
    e
  ) => {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      if (!showSuggestions) setShowSuggestions(true);
      setHighlightIndex((prev) =>
        Math.min((prev < 0 ? -1 : prev) + 1, suggestions.length - 1)
      );
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setHighlightIndex((prev) => Math.max(prev - 1, -1));
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (showSuggestions && highlightIndex >= 0) {
        const chosen = suggestions[highlightIndex];
        if (chosen) setRawSearch(chosen);
      }
      triggerSearch();
    } else if (e.key === "Escape") {
      setShowSuggestions(false);
      setHighlightIndex(-1);
    }
  };

  const handleMaxPriceKeyDown: React.KeyboardEventHandler<HTMLInputElement> = (
    e
  ) => {
    if (e.key === "Enter") {
      e.preventDefault();
      triggerMaxPrice();
    }
  };

  if (loading && products.length === 0) {
    return (
      <>
        <Navbar />
        <main className="container mx-auto p-6">
          <h1 className="text-3xl font-bold mb-6 text-right">
            {t("productsPage.title")}
          </h1>
          <p className="text-center text-gray-600 text-lg">
            {t("productsPage.loading")}
          </p>
        </main>
        <Footer />
      </>
    );
  }

  const pageItems = buildPageWindow(currentPage, totalPages, PAGE_WINDOW);

  return (
    <>
      <Navbar />
      <main className="container mx-auto p-6">
        <div className="flex items-center justify-between mb-4">
          <h1 className="text-2xl md:text-3xl font-bold text-right">
            {t("productsPage.title")}
          </h1>

          <div className="flex items-center gap-2">
            <button
              onClick={() => {
                setRecentDays((prev) => {
                  const next = prev ? null : 7;
                  setCurrentPage(1);
                  return next;
                });
              }}
              className={`hidden relative px-3 py-2 rounded transition-colors duration-200 ${
                recentDays
                  ? "bg-black text-white"
                  : "bg-gray-100 text-black hover:bg-gray-300"
              }`}
              title={t("productsPage.recentUpdates.tooltip")}
            >
              {recentDays
                ? t("productsPage.recentUpdates.showAll")
                : t("productsPage.recentUpdates.showRecent")}
              {recentDays && typeof recentTotal === "number" && (
                <span className="absolute -top-2 -right-2 text-xs rounded-full bg-red-600 text-white px-2 py-0.5">
                  {recentTotal}
                </span>
              )}
            </button>

            {recentDays && (
              <select
                className="border rounded px-2 py-2"
                value={recentDays}
                onChange={(e) => {
                  const v = parseInt(e.target.value || "7", 10);
                  setRecentDays(Number.isFinite(v) && v > 0 ? v : 7);
                  setCurrentPage(1);

                  console.log("hi")
                }}
                title={t("productsPage.recentUpdates.daysTitle")}
              >
                <option value={7}>
                  {t("productsPage.recentUpdates.daysOptions.7")}
                </option>
                <option value={14}>
                  {t("productsPage.recentUpdates.daysOptions.14")}
                </option>
                <option value={30}>
                  {t("productsPage.recentUpdates.daysOptions.30")}
                </option>
              </select>
            )}
          </div>
        </div>

        {/* ✅ الدوائر بالأعلى + تمرير صور الفروع التلقائية */}
        <CategoryCircles
          categories={categoryMenu.length ? categoryMenu : categoryGroups}
          onFilter={handleCategorySelect}
          selectedMain={selectedMainCategory}
          selectedSub={selectedSubCategory}
          loading={loadingCategories}
          subCategoryImages={subCategoryImagesFromData}
          labelMapper={translateCategoryLabel}
        />

        {/* فلاتر */}
        <section className="mt-4">
          <div className="flex flex-col sm:flex-row gap-2 mb-4">
            <div
              className="relative flex w-full sm:max-w-xl"
              ref={searchBoxWrapperRef}
            >
              <Input
                ref={searchRef}
                type="text"
                placeholder={t("productsPage.filters.searchPlaceholder")}
                value={rawSearch}
                autoComplete="off"
                onChange={(e) => {
                  setRawSearch(e.target.value);
                  setShowSuggestions(true);
                  setHighlightIndex(-1);
                }}
                onKeyDown={handleSearchKeyDown}
                onFocus={() => rawSearch && setShowSuggestions(true)}
                className="pr-12"
              />
              <button
                type="button"
                onClick={triggerSearch}
                className="absolute inset-y-0 left-0 sm:left-auto sm:right-0 sm:inset-y-0 flex items-center justify-center w-12 bg-black text-white rounded-r-md sm:rounded-l-none sm:rounded-r-md hover:bg-gray-800"
                title={t("productsPage.filters.searchButtonTitle")}
              >
                <svg
                  viewBox="0 0 24 24"
                  width="20"
                  height="20"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <circle cx="11" cy="11" r="8" />
                  <line x1="21" y1="21" x2="16.65" y2="16.65" />
                </svg>
              </button>

              {showSuggestions && suggestions.length > 0 && (
                <ul
                  className="absolute top-full mt-1 w-full z-20 bg-white border rounded-md shadow-lg max-h-64 overflow-auto text-right"
                  role="listbox"
                >
                  {suggestions.map((s, idx) => (
                    <li
                      key={`${s}-${idx}`}
                      role="option"
                      aria-selected={idx === highlightIndex}
                      onMouseDown={(e) => {
                        e.preventDefault();
                        setRawSearch(s);
                        setShowSuggestions(false);
                        setHighlightIndex(-1);
                        setTimeout(() => triggerSearch(), 0);
                      }}
                      className={`px-3 py-2 cursor-pointer transition-colors ${
                        idx === highlightIndex
                          ? "bg-gray-200"
                          : "hover:bg-gray-100"
                      }`}
                    >
                      {s}
                    </li>
                  ))}
                </ul>
              )}
            </div>

            <div className="relative flex w-full sm:max-w-xs">
              <Input
                ref={maxPriceRef}
                type="number"
                placeholder={t("productsPage.filters.pricePlaceholder")}
                value={rawMaxPrice}
                onChange={(e) => setRawMaxPrice(e.target.value)}
                onKeyDown={handleMaxPriceKeyDown}
                className="pr-16"
              />
              <button
                type="button"
                onClick={triggerMaxPrice}
                className="absolute inset-y-0 left-0 sm:left-auto sm:right-0 sm:inset-y-0 flex items-center justify-center px-3 bg-black text-white rounded-r-md sm:rounded-l-none sm:rounded-r-md hover:bg-gray-800"
                title={t("productsPage.filters.applyPriceTitle")}
              >
                {t("productsPage.filters.applyPrice")}
              </button>
            </div>

            {canUseOwnership && (
              <select
                className="border rounded px-3 py-2"
                value={ownershipFilter}
                onChange={(e) => {
                  setOwnershipFilter(e.target.value as OwnershipFilter);
                  setCurrentPage(1);
                }}
                title={t("productsPage.filters.ownership.title")}
              >
                <option value="all">
                  {t("productsPage.filters.ownership.options.all")}
                </option>
                <option value="ours">
                  {t("productsPage.filters.ownership.options.ours")}
                </option>
                <option value="local">
                  {t("productsPage.filters.ownership.options.local")}
                </option>
              </select>
            )}
          </div>

          <div className="flex flex-col sm:flex-row gap-2 mb-6">
            <select
              className="border rounded px-3 py-2"
              value={selectedColorSlug}
              onChange={(e) => {
                setSelectedColorSlug(e.target.value);
                setCurrentPage(1);
              }}
              disabled={
                loadingFacets || (!!facetsError && facets.colors.length === 0)
              }
              title={
                loadingFacets
                  ? t("productsPage.filters.colors.loadingTitle")
                  : facetsError && facets.colors.length === 0
                  ? t("productsPage.filters.colors.preFilterTitle")
                  : undefined
              }
            >
              <option value="">
                {loadingFacets
                  ? t("productsPage.filters.colors.loadingOption")
                  : facets.colors.length
                  ? t("productsPage.filters.colors.allOption")
                  : t("productsPage.filters.colors.promptOption")}
              </option>
              {facets.colors.map((c) => {
                const label = getLocalizedText(getColorLabel(c.name), locale);
                return (
                  <option key={c.slug} value={c.slug}>
                    {label || c.name}
                  </option>
                );
              })}
            </select>

            <select
              className="border rounded px-3 py-2"
              value={selectedMeasureSlug}
              onChange={(e) => {
                setSelectedMeasureSlug(e.target.value);
                setCurrentPage(1);
              }}
              disabled={
                loadingFacets || (!!facetsError && facets.measures.length === 0)
              }
              title={
                loadingFacets
                  ? t("productsPage.filters.measures.loadingTitle")
                  : facetsError && facets.measures.length === 0
                  ? t("productsPage.filters.measures.preFilterTitle")
                  : undefined
              }
            >
              <option value="">
                {loadingFacets
                  ? t("productsPage.filters.measures.loadingOption")
                  : facets.measures.length
                  ? t("productsPage.filters.measures.allOption")
                  : t("productsPage.filters.measures.promptOption")}
              </option>
              {facets.measures.map((m) => (
                <option key={m.slug} value={m.slug}>
                  {m.name}
                </option>
              ))}
            </select>

            {(selectedColorSlug || selectedMeasureSlug) && (
              <button
                onClick={() => {
                  setSelectedColorSlug("");
                  setSelectedMeasureSlug("");
                  setCurrentPage(1);
                }}
                className="px-3 py-2 rounded bg-gray-100 hover:bg-gray-200"
              >
                {t("productsPage.filters.resetColorMeasure")}
              </button>
            )}
          </div>
        </section>

        {products.length === 0 ? (
          <p className="text-center text-gray-600 text-lg">
            {t("productsPage.emptyState")}
          </p>
        ) : (
          <>
            {/* ✅ عمودين على الموبايل، 3 أعمدة من md وفوق */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-3 sm:gap-4 md:gap-6 items-start">
              {products.map((product) => (
                <ProductCard key={product._id} product={product} />
              ))}
            </div>

            <div className="mt-6 flex flex-col items-center gap-4">
              <div className="sm:hidden w-full">
                <div className="w-full overflow-x-auto">
                  <Pagination>
                    <PaginationContent className="justify-center">
                      <PaginationItem>
                        <PaginationNext
                          href="#"
                          aria-disabled={currentPage === totalPages}
                          className={
                            currentPage === totalPages
                              ? "pointer-events-none opacity-50"
                              : ""
                          }
                          onClick={(e) => {
                            e.preventDefault();
                            if (currentPage < totalPages)
                              setCurrentPage((p) =>
                                Math.min(totalPages, p + 1)
                              );
                          }}
                        />
                      </PaginationItem>

                      <PaginationItem>
                        <PaginationLink
                          href="#"
                          isActive
                          onClick={(e) => e.preventDefault()}
                          className="text-xs px-2"
                        >
                          {currentPage} / {totalPages}
                        </PaginationLink>
                      </PaginationItem>

                      <PaginationItem>
                        <PaginationPrevious
                          href="#"
                          aria-disabled={currentPage === 1}
                          className={
                            currentPage === 1
                              ? "pointer-events-none opacity-50"
                              : ""
                          }
                          onClick={(e) => {
                            e.preventDefault();
                            if (currentPage > 1)
                              setCurrentPage((p) => Math.max(1, p - 1));
                          }}
                        />
                      </PaginationItem>
                    </PaginationContent>
                  </Pagination>
                </div>

                <div className="mt-3 flex items-center justify-center gap-2">
                  <span className="text-sm text-gray-700">
                    {t("productsPage.pagination.goTo")}
                  </span>
                  <Select
                    value={String(currentPage)}
                    onValueChange={(v) => setCurrentPage(Number(v))}
                  >
                    <SelectTrigger className="w-28">
                      <SelectValue
                        placeholder={t(
                          "productsPage.pagination.selectPlaceholder"
                        )}
                      />
                    </SelectTrigger>
                    <SelectContent>
                      {Array.from({ length: totalPages }, (_, i) => i + 1).map(
                        (p) => (
                          <SelectItem key={p} value={String(p)}>
                            {p}
                          </SelectItem>
                        )
                      )}
                    </SelectContent>
                  </Select>
                </div>
              </div>

              <div className="hidden sm:flex flex-col items-center gap-3 w-full">
                <div className="w-full overflow-x-auto">
                  <Pagination>
                    <PaginationContent className="rtl:flex-row-reverse justify-center">
                      <PaginationItem>
                        <PaginationPrevious
                          href="#"
                          aria-disabled={currentPage === 1}
                          className={
                            currentPage === 1
                              ? "pointer-events-none opacity-50"
                              : ""
                          }
                          onClick={(e) => {
                            e.preventDefault();
                            if (currentPage > 1)
                              setCurrentPage((p) => Math.max(1, p - 1));
                          }}
                        />
                      </PaginationItem>

                      {pageItems.map((item, idx) =>
                        item === "ellipsis" ? (
                          <PaginationItem key={`ellipsis-${idx}`}>
                            <PaginationEllipsis />
                          </PaginationItem>
                        ) : (
                          <PaginationItem key={item}>
                            <PaginationLink
                              href="#"
                              isActive={currentPage === item}
                              onClick={(e) => {
                                e.preventDefault();
                                setCurrentPage(item);
                              }}
                            >
                              {item}
                            </PaginationLink>
                          </PaginationItem>
                        )
                      )}

                      <PaginationItem>
                        <PaginationNext
                          href="#"
                          aria-disabled={currentPage === totalPages}
                          className={
                            currentPage === totalPages
                              ? "pointer-events-none opacity-50"
                              : ""
                          }
                          onClick={(e) => {
                            e.preventDefault();
                            if (currentPage < totalPages)
                              setCurrentPage((p) =>
                                Math.min(totalPages, p + 1)
                              );
                          }}
                        />
                      </PaginationItem>
                    </PaginationContent>
                  </Pagination>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-sm text-gray-700">
                    {t("productsPage.pagination.goToPage")}
                  </span>
                  <Select
                    value={String(currentPage)}
                    onValueChange={(v) => setCurrentPage(Number(v))}
                  >
                    <SelectTrigger className="w-32">
                      <SelectValue
                        placeholder={t(
                          "productsPage.pagination.selectPlaceholder"
                        )}
                      />
                    </SelectTrigger>
                    <SelectContent className="max-h-40 overflow-y-auto">
                      {Array.from({ length: totalPages }, (_, i) => i + 1).map(
                        (p) => (
                          <SelectItem key={p} value={String(p)}>
                            {p}
                          </SelectItem>
                        )
                      )}
                    </SelectContent>
                  </Select>
                  <span className="text-sm text-gray-500">
                    {t("productsPage.pagination.total", { count: totalPages })}
                  </span>
                </div>
              </div>
            </div>
          </>
        )}
      </main>
      <Footer />
    </>
  );
};

export default Products;
