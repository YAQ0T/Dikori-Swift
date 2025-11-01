// components/ThemeToggle.tsx
import { useEffect, useState } from "react";
import { Moon, Sun } from "lucide-react";

const ThemeToggle = () => {
  const [isDark, setIsDark] = useState(false);

  useEffect(() => {
    const storedTheme = localStorage.getItem("theme");
    const prefersDark = storedTheme === "dark"; // فقط true إذا اختر المستخدم "dark" سابقًا

    setIsDark(prefersDark);
    document.documentElement.classList.toggle("dark", prefersDark);
  }, []);

  const toggleTheme = () => {
    const newTheme = !isDark;
    setIsDark(newTheme);
    document.documentElement.classList.toggle("dark", newTheme);
    localStorage.setItem("theme", newTheme ? "dark" : "light");
  };

  return (
    <div className="me-10">
      <button
        onClick={toggleTheme}
        className={`relative w-14 h-8 rounded-full transition-colors duration-300 
        ${isDark ? "bg-yellow-400" : "bg-gray-300"}`}
      >
        {/* Thumb */}
        <span
          className={`absolute top-1 left-1 w-6 h-6 rounded-full bg-black transition-all duration-300
          ${isDark ? "translate-x-6" : "translate-x-0"}`}
        />

        {/* Icon inside thumb */}
        <span className="absolute top-1.5 left-1.5 text-white text-xs pointer-events-none transition-all duration-300 me-0.5 mt-0.5">
          {isDark ? <Moon size={16} /> : <Sun size={16} />}
        </span>
      </button>
    </div>
  );
};

export default ThemeToggle;
