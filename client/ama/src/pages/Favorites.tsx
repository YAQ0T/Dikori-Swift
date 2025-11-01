import { Link } from "react-router-dom";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import ProductCard from "@/components/ProductCard";
import { Button } from "@/components/ui/button";
import { useFavorites } from "@/context/FavoritesContext";
import { useTranslation } from "@/i18n";

const Favorites: React.FC = () => {
  const { favorites } = useFavorites();
  const { t } = useTranslation();
  const hasFavorites = favorites.length > 0;

  return (
    <>
      <Navbar />
      <main className="container mx-auto p-6 text-right min-h-[60vh]">
        <div className="flex items-start justify-between gap-4 mb-6">
          <h1 className="text-3xl font-bold">{t("favoritesPage.title")}</h1>
          {hasFavorites && (
            <span className="text-sm text-muted-foreground">
              {t("favoritesPage.count", { count: favorites.length })}
            </span>
          )}
        </div>

        {hasFavorites ? (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {favorites.map((product) => (
              <ProductCard key={product._id} product={product} />
            ))}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center py-16 gap-4 text-center">
            <p className="text-muted-foreground text-lg">
              {t("favoritesPage.empty")}
            </p>
            <Button asChild>
              <Link to="/products">{t("favoritesPage.browse")}</Link>
            </Button>
          </div>
        )}
      </main>
      <Footer />
    </>
  );
};

export default Favorites;
