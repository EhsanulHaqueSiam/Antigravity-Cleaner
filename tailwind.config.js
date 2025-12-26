/** @type {import('tailwindcss').Config} */
module.exports = {
    content: [
        "./src/index.html",
        "./src/**/*.{js,ts,jsx,tsx}",
    ],
    theme: {
        extend: {
            colors: {
                background: "#09090b", // zinc-950
                surface: "#18181b",    // zinc-900
                primary: "#3b82f6",    // blue-500
                secondary: "#a855f7",  // purple-500
                accent: "#ec4899",     // pink-500
            }
        },
    },
    plugins: [],
}
