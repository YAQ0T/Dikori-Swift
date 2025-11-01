import { useId } from "react";

import { useLanguage } from "@/context/LanguageContext";

const LANGUAGE_OPTIONS = [
  { code: "ar", label: "العربية" },
  { code: "he", label: "עברית" },
] as const;

type LanguageCode = (typeof LANGUAGE_OPTIONS)[number]["code"];

interface LanguageToggleProps {
  className?: string;
}

const LanguageToggle = ({ className }: LanguageToggleProps) => {
  const { locale, setLocale } = useLanguage();
  const selectId = useId();

  return (
    <div className={className}>
      <label htmlFor={selectId} className="sr-only">
        اختر اللغة
      </label>
      <select
        id={selectId}
        value={locale}
        onChange={(event) => setLocale(event.target.value as LanguageCode)}
        className="h-9 rounded-md border border-border bg-background px-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
      >
        {LANGUAGE_OPTIONS.map((option) => (
          <option key={option.code} value={option.code}>
            {option.label}
          </option>
        ))}
      </select>
    </div>
  );
};

export default LanguageToggle;
