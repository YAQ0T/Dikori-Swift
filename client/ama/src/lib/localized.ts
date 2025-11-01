import type { SupportedLocale } from "@/context/LanguageContext";

export type LocalizedText =
  | string
  | null
  | undefined
  | {
      ar?: string | null;
      he?: string | null;
    };

export type LocalizedObject = {
  ar: string;
  he: string;
};

export const emptyLocalized: LocalizedObject = { ar: "", he: "" };

type EnsureLocalizedOptions = {
  trim?: boolean;
};

const normalizeValue = (
  value: string | null | undefined,
  { trim = true }: EnsureLocalizedOptions
) => {
  if (value == null) {
    return "";
  }

  const stringified = value.toString();
  return trim ? stringified.trim() : stringified;
};

export const ensureLocalizedObject = (
  value: LocalizedText,
  options: EnsureLocalizedOptions = {}
): LocalizedObject => {
  const { trim = true } = options;

  if (!value) {
    return { ...emptyLocalized };
  }

  if (typeof value === "string") {
    const normalized = trim ? value.trim() : value;
    return { ar: normalized, he: "" };
  }

  return {
    ar: normalizeValue(value.ar, { trim }),
    he: normalizeValue(value.he, { trim }),
  };
};

export const getLocalizedText = (
  value: LocalizedText,
  locale: SupportedLocale,
  fallbackLocale: SupportedLocale = "ar"
): string => {
  const normalized = ensureLocalizedObject(value);
  const primary = normalized[locale]?.trim();
  if (primary) {
    return primary;
  }

  const fallback = normalized[fallbackLocale]?.trim();
  if (fallback) {
    return fallback;
  }

  const alternative = locale === "ar" ? normalized.he : normalized.ar;
  return alternative.trim();
};
