import React from "react";
import { Link } from "react-router-dom";
import VisaLogo from "@/assets/Visa_Inc._logo.svg";
import MastercardLogo from "@/assets/Mastercard-logo.svg";
import { useTranslation } from "@/i18n";

const Footer: React.FC = () => {
  const { t } = useTranslation();
  const year = new Date().getFullYear();
  const socialLinks = t("footer.socialLinks", {
    returnObjects: true,
  }) as { key: string; href: string; label: string }[];

  return (
    <footer className="dark:text-gray-200 mt-12 border-t pt-6 text-center text-gray-600">
      <p>{t("footer.rights", { year })}</p>
      <p className="dark:text-gray-200 mt-2">{t("footer.contact")}</p>

      {/* روابط السوشيال ميديا */}
      <div className="dark:text-gray-200 mt-4 flex justify-center gap-4">
        {socialLinks.map((link) => (
          <a
            key={link.key}
            href={link.href}
            className="dark:text-gray-200 hover:text-black"
          >
            {link.label}
          </a>
        ))}
      </div>

      {/* روابط قانونية */}
      <div className="dark:text-gray-200 mt-4 flex justify-center gap-4 text-sm">
        <Link
          to="/privacy-policy"
          className="dark:text-gray-200 hover:text-black"
        >
          {t("footer.legal.privacy")}
        </Link>
        <Link to="/terms" className="dark:text-gray-200 hover:text-black">
          {t("footer.legal.terms")}
        </Link>
        <Link to="/returnes" className="dark:text-gray-200 hover:text-black">
          سياسة الإرجاع والاستبدال
        </Link>
      </div>

      {/* شعارات الدفع */}
      <div className="mt-6 flex justify-center gap-6">
        <img src={VisaLogo} alt="Visa" className="h-8 object-contain" />
        <img
          src={MastercardLogo}
          alt="Mastercard"
          className="h-8 object-contain"
        />
      </div>
    </footer>
  );
};

export default Footer;
