// src/pages/Home.tsx
import { useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { useNavigate } from "react-router-dom";
import Footer from "@/components/Footer";
import Navbar from "@/components/Navbar";
import { useTranslation } from "@/i18n";
import { getLocalizedText, type LocalizedText } from "@/lib/localized";
import { useLanguage, type SupportedLocale } from "@/context/LanguageContext";

// ====== أنواع بسيطة للمنتج ======
type Product = {
  _id?: string;
  id?: string | number;
  name?: LocalizedText;
  title?: LocalizedText;
  price?: number;
  images?: string[];
  image?: string;
  mainImage?: string;
  slug?: string;
};

type LocalizedCategory = {
  key: string;
  label: string;
  value: string;
  img: string;
};

type LocalizedBenefit = {
  key: string;
  icon: string;
  title: string;
  description: string;
};

type LocalizedFallbackProduct = {
  key: string;
  id: number | string;
  name: LocalizedText;
  price: number;
  image: string;
};

const getId = (p: Product) => p._id ?? p.id ?? p.slug ?? String(Math.random());
const getImage = (p: Product) =>
  p.images?.[0] ||
  p.image ||
  p.mainImage ||
  "https://placehold.co/600x400/png?text=No+Image";
const getName = (p: Product, fallback: string, locale: SupportedLocale) =>
  getLocalizedText(p.name ?? p.title ?? fallback, locale) || fallback;

// ====== بطاقة منتج (مُصغّرة للموبايل) ======
const ProductCard = ({
  product,
  fallbackName,
  locale,
}: {
  product: Product;
  fallbackName: string;
  locale: SupportedLocale;
}) => {
  const navigate = useNavigate();
  const { t } = useTranslation();
  const img = getImage(product);
  const name = getName(product, fallbackName, locale);

  const detailId =
    (typeof product._id === "string" && product._id) ||
    (typeof product.id === "string" && product.id) ||
    (typeof product.id === "number" && String(product.id)) ||
    "";

  const goToDetails = () => {
    if (detailId) navigate(`/products/${detailId}`);
    else navigate(`/products`);
  };

  return (
    <div className="group rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden bg-white dark:bg-gray-900">
      <button
        type="button"
        onClick={goToDetails}
        className="aspect-[3/4] w-full overflow-hidden bg-gray-50 dark:bg-gray-800 block"
        aria-label={t("home.fallback.viewAria", { name })}
      >
        <img
          src={img}
          alt={name}
          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
          loading="lazy"
        />
      </button>
      <div className="p-3 sm:p-4 text-right">
        <h3 className="font-semibold line-clamp-1 text-sm sm:text-base">
          {name}
        </h3>
        {typeof product.price === "number" ? (
          <p className="text-xs sm:text-sm text-gray-600 dark:text-gray-300 mt-1">
            {product.price.toFixed(2)} ₪
          </p>
        ) : (
          <p className="text-xs sm:text-sm text-gray-600 dark:text-gray-300 mt-1">
            {t("home.fallback.noPrice")}
          </p>
        )}
        <div className="mt-2 sm:mt-3 flex justify-end">
          <Button
            variant="default"
            className="h-8 px-3 text-xs sm:h-9 sm:px-4 sm:text-sm"
            onClick={goToDetails}
          >
            {t("home.fallback.viewProduct")}
          </Button>
        </div>
      </div>
    </div>
  );
};

// ====== مكوّن شبكة منتجات (ينادي API مع سقوط افتراضي) — موبايل أصغر ======
const ProductsSection = ({
  title,
  endpoint,
  fallbackProducts,
  fallbackName,
  locale,
}: {
  title: string;
  endpoint: string; // مثال: "/api/home-collections/recommended"
  fallbackProducts: Product[];
  fallbackName: string;
  locale: SupportedLocale;
}) => {
  const [items, setItems] = useState<Product[] | null>(null);
  const { t } = useTranslation();

  useEffect(() => {
    let stop = false;
    (async () => {
      try {
        const base = import.meta.env.VITE_API_URL || "";
        const url =
          endpoint.startsWith("http") || endpoint.startsWith("//")
            ? endpoint
            : `${base}${endpoint}`;
        const res = await fetch(url);
        if (!res.ok) throw new Error("bad status");
        const data = await res.json();
        const list: Product[] = Array.isArray(data)
          ? data
          : Array.isArray(data?.products)
          ? data.products
          : Array.isArray(data?.data)
          ? data.data
          : [];
        if (!stop && list.length) setItems(list.slice(0, 8));
        if (!stop && !list.length) setItems(fallbackProducts);
      } catch {
        if (!stop) setItems(fallbackProducts);
      }
    })();
    return () => {
      stop = true;
    };
  }, [endpoint]);

  return (
    <section className="mt-10 sm:mt-14">
      <div className="flex items-center justify-between mb-3 sm:mb-4">
        <h2 className="text-xl sm:text-2xl font-semibold text-right">
          {title}
        </h2>
        <Button
          variant="ghost"
          className="h-8 px-2 text-xs sm:h-9 sm:px-3 sm:text-sm"
          onClick={() => (window.location.href = "/products")}
        >
          {t("home.actions.browseAll")}
      </Button>
      </div>
      <div className="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-3 sm:gap-6">
        {(items ?? fallbackProducts).map((p) => (
          <ProductCard
            key={getId(p)}
            product={p}
            fallbackName={fallbackName}
            locale={locale}
          />
        ))}
      </div>
    </section>
  );
};

const Home: React.FC = () => {
  const navigate = useNavigate();
  const { t } = useTranslation();
  const { locale } = useLanguage();

  const localizedCategories = t("home.categories", {
    returnObjects: true,
  }) as LocalizedCategory[];

  const benefits = t("home.benefits", {
    returnObjects: true,
  }) as LocalizedBenefit[];

  const fallbackProducts = useMemo(() => {
    const list = t("home.fallback.products", {
      returnObjects: true,
    }) as LocalizedFallbackProduct[];
    return list.map((item) => ({
      id: item.id,
      name: item.name,
      price: item.price,
      image: item.image,
    }));
  }, [t]);

  const fallbackName = t("home.fallback.noName");

  const goToCategory = (main: string, sub?: string) => {
    const params = new URLSearchParams();
    params.set("category", main);
    if (sub) params.set("sub", sub);
    navigate(`/products?${params.toString()}`);
  };

  return (
    <>
      <Navbar />
      <main className="container mx-auto px-4 py-4 md:p-6">
        {/* البطل — أصغر للموبايل */}
        <section className="text-right">
          <h1 className="text-2xl md:text-4xl font-bold mb-3 md:mb-4">
            {t("home.hero.title")}
          </h1>
          <p className="text-sm md:text-lg mb-5 md:mb-6 text-gray-700 dark:text-gray-200">
            {t("home.hero.subtitle")}
          </p>
          <div className="flex justify-end mb-6 md:mb-10">
            <Button
              className="h-9 px-4 text-sm md:h-10 md:px-5 md:text-base"
              onClick={() => navigate(`/products`)}
            >
              {t("home.actions.startShopping")}
            </Button>
          </div>
        </section>

        {/* الأقسام الرئيسية () — أحجام أصغر للموبايل */}
        <section className="mt-2">
          <h2 className="text-xl md:text-2xl font-semibold mb-4 md:mb-6 text-right">
            {t("home.sections.categories")}
          </h2>
          <div className="grid grid-cols-3 xs:grid-cols-4 sm:grid-cols-4 md:grid-cols-5 xl:grid-cols-6 gap-3 sm:gap-6">
            {localizedCategories.map((c) => (
              <div
                key={c.key}
                onClick={() => goToCategory(c.value as string)}
                className="cursor-pointer flex flex-col items-center text-center"
              >
                <div
                  className="
                    w-20 h-20
                    sm:w-24 sm:h-24
                    md:w-28 md:h-28
                    lg:w-32 lg:h-32
                    xl:w-36 xl:h-36
                    rounded-md overflow-hidden
                    bg-white dark:bg-gray-900
                    border border-gray-200 dark:border-gray-700
                    shadow-sm hover:shadow-md transition-shadow duration-300
                  "
                >
                  <img
                    src={c.img}
                    alt={c.label}
                    className="w-full h-full object-cover"
                    loading="lazy"
                  />
                </div>
                <span className="mt-2 sm:mt-3 text-[11px] sm:text-sm font-medium">
                  {c.label}
                </span>
              </div>
            ))}
          </div>
        </section>

        {/* ماذا نقدّم (4 بطاقات فوائد) — مصغّر للموبايل */}
        <section className="mt-10 md:mt-14">
          <h2 className="text-xl md:text-2xl font-semibold mb-4 md:mb-6 text-right">
            {t("home.sections.benefits")}
          </h2>
          <div className="grid grid-cols-2 sm:grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-6">
            {benefits.map((b) => (
              <div
                key={b.key}
                className="rounded-xl sm:rounded-2xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 p-3 sm:p-5 text-right hover:shadow-md transition-shadow duration-300"
              >
                <div className="flex justify-end">
                  <div className="w-10 h-10 sm:w-12 sm:h-12 rounded-lg sm:rounded-xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center">
                    <img
                      src={b.icon}
                      alt={b.title}
                      className="w-6 h-6 sm:w-7 sm:h-7"
                      loading="lazy"
                    />
                  </div>
                </div>
                <h3 className="mt-3 sm:mt-4 font-semibold text-sm sm:text-base">
                  {b.title}
                </h3>
                <p className="text-[11px] sm:text-sm text-gray-600 dark:text-gray-300 mt-1">
                  {b.description}
                </p>
              </div>
            ))}
          </div>
        </section>

        {/* منتجات مقترحة — من home-collections */}
        <ProductsSection
          title={t("home.sections.recommended")}
          endpoint="/api/home-collections/recommended"
          fallbackProducts={fallbackProducts}
          fallbackName={fallbackName}
          locale={locale}
        />

        {/* وصل حديثًا — من home-collections */}
        <ProductsSection
          title={t("home.sections.newArrivals")}
          endpoint="/api/home-collections/new"
          fallbackProducts={fallbackProducts}
          fallbackName={fallbackName}
          locale={locale}
        />
      </main>
      <Footer />
    </>
  );
};

export default Home;
