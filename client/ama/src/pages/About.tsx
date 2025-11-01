import React from "react";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { Button } from "@/components/ui/button";
import { Link } from "react-router-dom";

const About: React.FC = () => {
  return (
    <>
      <Navbar />
      <main className="container mx-auto p-6">
        <h1 className="text-3xl font-bold mb-4 text-right">من نحن</h1>
        <p className="dark:text-gray-200 text-lg mb-6 text-right text-gray-700 leading-7">
          متجر <span className="font-semibold">ديكوري</span> هو وجهتك الأولى
          لشراء مستلزمات النجارة، أقمشة التنجيد، وخامات صناعة الكنب بجودة عالية
          وأسعار منافسة. نهدف لتقديم أفضل تجربة تسوق عبر الإنترنت لعملائنا في
          الضفة الغربية والداخل.
        </p>

        <p className="dark:text-gray-200 text-lg mb-6 text-right text-gray-700 leading-7">
          تأسس المتجر على يد فريق محترف لديه خبرة طويلة في مجال تجارة مستلزمات
          الأثاث والصناعات الخشبية. نحن ملتزمون بتوفير منتجات أصلية وتوصيل سريع
          ودعم مستمر لعملائنا.
        </p>

        <div className="text-right">
          <Link to="/contact">
            <Button>تواصل معنا</Button>
          </Link>
        </div>
      </main>
      <Footer />
    </>
  );
};

export default About;
