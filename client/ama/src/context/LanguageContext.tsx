import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";

import i18n, { resources } from "@/i18n";

export type SupportedLocale = keyof typeof resources;

type TextDirection = "ltr" | "rtl";

interface LanguageContextValue {
  locale: SupportedLocale;
  direction: TextDirection;
  setLocale: (locale: SupportedLocale) => void;
}

const RTL_LANGUAGES = new Set<SupportedLocale>(["ar", "he"]);

const STORAGE_KEY = "app-language";

const LanguageContext = createContext<LanguageContextValue | undefined>(
  undefined
);

const resolveDirection = (locale: SupportedLocale): TextDirection =>
  RTL_LANGUAGES.has(locale) ? "rtl" : "ltr";

const isSupportedLocale = (value: string): value is SupportedLocale =>
  value in resources;

const getInitialLocale = (): SupportedLocale => {
  if (typeof window === "undefined") {
    return (i18n.language as SupportedLocale) ?? "ar";
  }

  const stored = localStorage.getItem(STORAGE_KEY);

  if (stored && isSupportedLocale(stored)) {
    return stored;
  }

  return (i18n.language as SupportedLocale) ?? "ar";
};

export const LanguageProvider: React.FC<React.PropsWithChildren> = ({
  children,
}) => {
  const [locale, setLocaleState] = useState<SupportedLocale>(getInitialLocale);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    localStorage.setItem(STORAGE_KEY, locale);
  }, [locale]);

  useEffect(() => {
    void i18n.changeLanguage(locale);
  }, [locale]);

  useEffect(() => {
    if (typeof document === "undefined") {
      return;
    }

    document.documentElement.lang = locale;
    document.documentElement.dir = resolveDirection(locale);
  }, [locale]);

  useEffect(() => {
    const handleLanguageChange = (nextLocale: string) => {
      if (isSupportedLocale(nextLocale) && nextLocale !== locale) {
        setLocaleState(nextLocale);
      }
    };

    i18n.on("languageChanged", handleLanguageChange);

    return () => {
      i18n.off("languageChanged", handleLanguageChange);
    };
  }, [locale]);

  const setLocale = useCallback((value: SupportedLocale) => {
    setLocaleState(value);
  }, []);

  const direction = resolveDirection(locale);

  const value = useMemo(
    () => ({
      locale,
      direction,
      setLocale,
    }),
    [direction, locale, setLocale]
  );

  return (
    <LanguageContext.Provider value={value}>
      {children}
    </LanguageContext.Provider>
  );
};

export const useLanguage = (): LanguageContextValue => {
  const context = useContext(LanguageContext);

  if (!context) {
    throw new Error("useLanguage must be used within a LanguageProvider");
  }

  return context;
};
