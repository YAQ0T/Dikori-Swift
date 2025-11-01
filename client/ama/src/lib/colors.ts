import type { LocalizedObject } from "@/lib/localized";

export const normalizeColorKey = (value: string): string =>
  value
    .normalize("NFKC")
    .replace(/[إأآ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/ـ/g, "")
    .toLowerCase()
    .replace(/[\s_-]+/g, "")
    .trim();

type ColorEntry = {
  keys: string[];
  label: LocalizedObject;
};

const colorEntries: ColorEntry[] = [
  {
    keys: ["أسود", "اسود", "black"],
    label: { ar: "أسود", he: "שחור" },
  },
  {
    keys: ["أبيض", "ابيض", "white"],
    label: { ar: "أبيض", he: "לבן" },
  },
  {
    keys: ["رمادي", "رمادى", "gray", "grey"],
    label: { ar: "رمادي", he: "אפור" },
  },
  {
    keys: ["رمادي فاتح", "lightgray", "lightgrey"],
    label: { ar: "رمادي فاتح", he: "אפור בהיר" },
  },
  {
    keys: ["رمادي غامق", "darkgray", "darkgrey"],
    label: { ar: "رمادي غامق", he: "אפור כהה" },
  },
  {
    keys: ["فضي", "فضى", "silver"],
    label: { ar: "فضي", he: "כסוף" },
  },
  {
    keys: ["ذهبي", "دهبي", "gold"],
    label: { ar: "ذهبي", he: "זהב" },
  },
  {
    keys: ["أحمر", "احمر", "red"],
    label: { ar: "أحمر", he: "אדום" },
  },
  {
    keys: ["خمري", "burgundy"],
    label: { ar: "خمري", he: "בורדו" },
  },
  {
    keys: ["عنابي", "maroon", "wine"],
    label: { ar: "عنابي", he: "אדום יין" },
  },
  {
    keys: ["أزرق", "ازرق", "blue"],
    label: { ar: "أزرق", he: "כחול" },
  },
  {
    keys: ["سماوي", "skyblue", "lightblue"],
    label: { ar: "سماوي", he: "תכלת" },
  },
  {
    keys: ["كحلي", "navy"],
    label: { ar: "كحلي", he: "כחול כהה" },
  },
  {
    keys: ["تركواز", "turquoise"],
    label: { ar: "تركواز", he: "טורקיז" },
  },
  {
    keys: ["أخضر", "اخضر", "green"],
    label: { ar: "أخضر", he: "ירוק" },
  },
  {
    keys: ["زيتي", "olive"],
    label: { ar: "زيتي", he: "ירוק זית" },
  },
  {
    keys: ["عسلي", "hazel", "honey"],
    label: { ar: "عسلي", he: "חום דבש" },
  },
  {
    keys: ["أصفر", "اصفر", "yellow"],
    label: { ar: "أصفر", he: "צהוב" },
  },
  {
    keys: ["برتقالي", "orange"],
    label: { ar: "برتقالي", he: "כתום" },
  },
  {
    keys: ["بنفسجي", "purple", "violet"],
    label: { ar: "بنفسجي", he: "סגול" },
  },
  {
    keys: ["ليلكي", "lilac"],
    label: { ar: "ليلكي", he: "לילך" },
  },
  {
    keys: ["زهري", "وردي", "pink", "rose"],
    label: { ar: "زهري", he: "ורוד" },
  },
  {
    keys: ["مشمشي", "خوخي", "peach", "apricot"],
    label: { ar: "مشمشي", he: "אפרסק" },
  },
  {
    keys: ["بيج", "beige"],
    label: { ar: "بيج", he: "בז'" },
  },
  {
    keys: ["سكري", "سكّري", "offwhite", "off-white", "ivory", "cream"],
    label: { ar: "سكري", he: "שמנת" },
  },
  {
    keys: ["بني", "بنى", "brown"],
    label: { ar: "بني", he: "חום" },
  },
  {
    keys: ["كوفي", "coffee", "cafe", "cafee"],
    label: { ar: "كوفي", he: "חום קפה" },
  },
  {
    keys: ["برونزي", "bronze"],
    label: { ar: "برونزي", he: "ברונזה" },
  },
];

const buildColorLabelMap = (): ReadonlyMap<string, LocalizedObject> => {
  const map = new Map<string, LocalizedObject>();
  for (const entry of colorEntries) {
    for (const key of entry.keys) {
      const normalized = normalizeColorKey(key);
      if (normalized) {
        map.set(normalized, entry.label);
      }
    }
  }
  return map;
};

export const colorLabelMap = buildColorLabelMap();

export const findColorLabel = (
  value?: string | null
): LocalizedObject | undefined => {
  if (!value) return undefined;
  const normalized = normalizeColorKey(value);
  if (!normalized) return undefined;
  return colorLabelMap.get(normalized);
};

export const getColorLabel = (value?: string | null): LocalizedObject => {
  const found = findColorLabel(value);
  if (found) return found;
  const fallback = value?.trim() ?? "";
  return { ar: fallback, he: fallback };
};
