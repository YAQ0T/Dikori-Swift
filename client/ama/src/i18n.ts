import i18n from "i18next";
import { initReactI18next } from "react-i18next";

import arCommon from "./locales/ar/common.json";
import heCommon from "./locales/he/common.json";

export const resources = {
  ar: {
    common: arCommon,
  },
  he: {
    common: heCommon,
  },
} as const;

i18n.use(initReactI18next).init({
  resources,
  lng: "ar",
  fallbackLng: "ar",
  supportedLngs: ["ar", "he"],
  defaultNS: "common",
  interpolation: {
    escapeValue: false,
  },
  returnNull: false,
});

export default i18n;
export { useTranslation } from "react-i18next";
