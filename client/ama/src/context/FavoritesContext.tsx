import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import type { ReactNode } from "react";
import type { LocalizedText } from "@/lib/localized";

export type FavoriteProduct = {
  _id: string;
  name: LocalizedText;
  description: LocalizedText;
  price: number;
  images?: string[];
  subCategory?: string;
};

type FavoritesContextType = {
  favorites: FavoriteProduct[];
  addFavorite: (product: FavoriteProduct) => void;
  removeFavorite: (productId: string) => void;
  toggleFavorite: (product: FavoriteProduct) => void;
  isFavorite: (productId: string) => boolean;
};

const FavoritesContext = createContext<FavoritesContextType | null>(null);

const normalizeFavorite = (
  item: Partial<FavoriteProduct>
): FavoriteProduct | null => {
  if (!item || !item._id) return null;
  return {
    _id: item._id,
    name: (item.name ?? "") as LocalizedText,
    description: (item.description ?? "") as LocalizedText,
    price: typeof item.price === "number" ? item.price : 0,
    images: Array.isArray(item.images) ? item.images : undefined,
    subCategory: item.subCategory,
  };
};

const STORAGE_KEY = "dikori_favorites_v1";

export const FavoritesProvider = ({ children }: { children: ReactNode }) => {
  const [favorites, setFavorites] = useState<FavoriteProduct[]>(() => {
    if (typeof window === "undefined") return [];
    try {
      const raw = window.localStorage.getItem(STORAGE_KEY);
      if (!raw) return [];
      const parsed = JSON.parse(raw) as Partial<FavoriteProduct>[];
      if (!Array.isArray(parsed)) return [];
      const normalized = parsed
        .map((item) => normalizeFavorite(item))
        .filter((item): item is FavoriteProduct => item !== null);
      const unique = new Map(normalized.map((item) => [item._id, item]));
      return Array.from(unique.values());
    } catch {
      return [];
    }
  });

  useEffect(() => {
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(favorites));
    } catch {
      // Ignore storage errors (quota, private mode, ...)
    }
  }, [favorites]);

  useEffect(() => {
    const handleStorage = (event: StorageEvent) => {
      if (event.key !== STORAGE_KEY) return;
      if (!event.newValue) {
        setFavorites([]);
        return;
      }
      try {
        const parsed = JSON.parse(event.newValue) as Partial<FavoriteProduct>[];
        if (Array.isArray(parsed)) {
          const normalized = parsed
            .map((item) => normalizeFavorite(item))
            .filter((item): item is FavoriteProduct => item !== null);
          setFavorites(normalized);
        }
      } catch {
        // ignore malformed payloads
      }
    };

    window.addEventListener("storage", handleStorage);
    return () => window.removeEventListener("storage", handleStorage);
  }, []);

  const addFavorite = useCallback((product: FavoriteProduct) => {
    setFavorites((prev) => {
      if (prev.some((item) => item._id === product._id)) return prev;
      const entry: FavoriteProduct = {
        ...product,
        price: product.price ?? 0,
      };
      return [...prev, entry];
    });
  }, []);

  const removeFavorite = useCallback((productId: string) => {
    setFavorites((prev) => prev.filter((item) => item._id !== productId));
  }, []);

  const toggleFavorite = useCallback((product: FavoriteProduct) => {
    setFavorites((prev) => {
      const exists = prev.some((item) => item._id === product._id);
      if (exists) {
        return prev.filter((item) => item._id !== product._id);
      }
      const entry: FavoriteProduct = {
        ...product,
        price: product.price ?? 0,
      };
      return [...prev, entry];
    });
  }, []);

  const isFavorite = useCallback(
    (productId: string) => favorites.some((item) => item._id === productId),
    [favorites]
  );

  const value = useMemo(
    () => ({
      favorites,
      addFavorite,
      removeFavorite,
      toggleFavorite,
      isFavorite,
    }),
    [favorites, addFavorite, removeFavorite, toggleFavorite, isFavorite]
  );

  return (
    <FavoritesContext.Provider value={value}>
      {children}
    </FavoritesContext.Provider>
  );
};

export const useFavorites = () => {
  const ctx = useContext(FavoritesContext);
  if (!ctx) {
    throw new Error("useFavorites must be used within a FavoritesProvider");
  }
  return ctx;
};
