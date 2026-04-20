const EDAMAM_APP_ID = process.env.EDAMAM_APP_ID;
const EDAMAM_APP_KEY = process.env.EDAMAM_APP_KEY;

const numberOrZero = (value) => {
	const parsed = Number(value);
	if (!Number.isFinite(parsed) || parsed < 0) return 0;
	return parsed;
};

const ARABIC_DIGIT_MAP = {
	"٠": "0",
	"١": "1",
	"٢": "2",
	"٣": "3",
	"٤": "4",
	"٥": "5",
	"٦": "6",
	"٧": "7",
	"٨": "8",
	"٩": "9",
};

const normalizeQuickAddText = (text) => {
	let normalized = (text || "").toString();

	for (const [arabicDigit, asciiDigit] of Object.entries(ARABIC_DIGIT_MAP)) {
		normalized = normalized.replace(new RegExp(arabicDigit, "g"), asciiDigit);
	}

	normalized = normalized
		.replace(/[\u0640]/g, "")
		.replace(/(\d)\s*[،,]\s*(\d)/g, "$1.$2")
		.replace(/\b(?:جرام|غرام|غم|غ)\b/gi, "g")
		.replace(/\b(?:كيلو\s*جرام|كيلو\s*غرام|كجم|كغ|كيلو)\b/gi, "kg")
		.replace(/\b(?:ملليلتر|مليلتر|ملي|مل)\b/gi, "ml")
		.replace(/\b(?:لتر)\b/gi, "l")
		.replace(/\b(?:اكواب|أكواب|كوب)\b/gi, "cup")
		.replace(/\b(?:ملعقة\s*كبيرة)\b/gi, "tbsp")
		.replace(/\b(?:ملعقة\s*صغيرة)\b/gi, "tsp")
		.replace(/\b(\d+)\s*[xX]\s*/g, "$1 ")
		.replace(/(\d)(kg|g|ml|l|oz|lb|cup|tbsp|tsp)\b/gi, "$1 $2")
		.replace(/[\n\r]+/g, ",")
		.replace(/[،؛]+/g, ",")
		.replace(/[|/]+/g, ",")
		.replace(/\s+/g, " ")
		.trim();

	return normalized;
};

const extractExplicitWeightGrams = (text) => {
	const normalized = normalizeQuickAddText(text).toLowerCase();
	if (!normalized) return 0;

	const patterns = [
		/(\d+(?:\.\d+)?)\s*(kg|kilogram(?:s)?|g|gram(?:s)?|gm|ml|l|cup(?:s)?|tbsp|tablespoon(?:s)?|tsp|teaspoon(?:s)?|oz|lb)\b/gi,
		/(\d+(?:\.\d+)?)\s*(?:liter|liters|litre|litres)\b/gi,
	];

	let total = 0;

	for (const pattern of patterns) {
		let match;
		while ((match = pattern.exec(normalized)) !== null) {
			const amount = numberOrZero(match[1]);
			const unit = (match[2] || "").toLowerCase();

			if (unit === "kg" || /kilogram/.test(unit)) {
				total += amount * 1000;
			} else if (unit === "g" || unit === "gm" || /gram/.test(unit)) {
				total += amount;
			} else if (unit === "ml") {
				total += amount;
			} else if (unit === "l" || /liter|litre/.test(unit)) {
				total += amount * 1000;
			} else if (unit === "cup") {
				total += amount * 240;
			} else if (unit === "tbsp") {
				total += amount * 15;
			} else if (unit === "tsp") {
				total += amount * 5;
			} else if (unit === "oz") {
				total += amount * 28.3495;
			} else if (unit === "lb") {
				total += amount * 453.592;
			}
		}
	}

	return Number(total.toFixed(1));
};

const getWeightSource = (text, explicitGrams, apiGrams) => {
	if (explicitGrams > 0) {
		return {
			grams: Number(explicitGrams.toFixed(1)),
			source: "input",
		};
	}

	return {
		grams: Number(numberOrZero(apiGrams).toFixed(1)),
		source: "api",
	};
};

const splitIngredientLines = (text) => {
	const normalized = normalizeQuickAddText(text);

	if (!normalized) return [];

	const parts = normalized
		.split(/\s*(?:,|\+| and | with | plus | و | مع )\s*/i)
		.map((part) => part.trim())
		.filter(Boolean);

	return parts.length > 0 ? parts : [normalized];
};

const nutrientValue = (source, key) => {
	if (!source || typeof source !== "object") return 0;
	return numberOrZero(source[key]?.quantity);
};

const mapEdamamIngredient = (ingredient) => {
	const parsed = Array.isArray(ingredient?.parsed) && ingredient.parsed.length > 0
		? ingredient.parsed[0]
		: null;

	const parsedNutrients = parsed?.nutrients || {};
	const calories = numberOrZero(parsedNutrients.ENERC_KCAL);
	const protein = numberOrZero(parsedNutrients.PROCNT);
	const carbs = numberOrZero(parsedNutrients.CHOCDF);
	const fat = numberOrZero(parsedNutrients.FAT);

	return {
		name:
			(parsed?.foodMatch || "").toString().trim() ||
			(ingredient?.food || "").toString().trim() ||
			(ingredient?.text || "").toString().trim() ||
			"Food item",
		quantity: numberOrZero(parsed?.quantity) || 1,
		unit: (parsed?.measure || "serving").toString().trim().toLowerCase() || "serving",
		grams: numberOrZero(ingredient?.weight),
		calories: Number(calories.toFixed(1)),
		protein: Number(protein.toFixed(1)),
		carbs: Number(carbs.toFixed(1)),
		fat: Number(fat.toFixed(1)),
	};
};

const analyzeQuickAddText = async (text, mealType = "snack") => {
	const mealName = (text || "").toString().trim();
	if (!mealName) {
		return {
			mealType,
			mealName: "",
			calories: 0,
			protein: 0,
			carbs: 0,
			fat: 0,
			grams: 0,
			items: [],
		};
	}

	if (!EDAMAM_APP_ID || !EDAMAM_APP_KEY) {
		throw new Error("Edamam credentials are missing on backend");
	}

	const ingr = splitIngredientLines(mealName);
	if (ingr.length === 0) {
		return {
			mealType,
			mealName,
			calories: 0,
			protein: 0,
			carbs: 0,
			fat: 0,
			grams: 0,
			items: [],
		};
	}

	const url = new URL("https://api.edamam.com/api/nutrition-details");
	url.searchParams.set("app_id", EDAMAM_APP_ID);
	url.searchParams.set("app_key", EDAMAM_APP_KEY);

	const response = await fetch(url, {
		method: "POST",
		headers: {
			"Content-Type": "application/json",
		},
		body: JSON.stringify({
			title: "Quick Add Meal",
			ingr,
		}),
	});

	const data = await response.json().catch(() => ({}));
	if (!response.ok) {
		const apiMessage =
			data?.message ||
			data?.error ||
			data?.details ||
			`Edamam request failed (${response.status})`;
		throw new Error(apiMessage);
	}

	const totalNutrients = data?.totalNutrients || {};
	const calories = numberOrZero(data?.calories);
	const protein = nutrientValue(totalNutrients, "PROCNT");
	const carbs = nutrientValue(totalNutrients, "CHOCDF");
	const fat = nutrientValue(totalNutrients, "FAT");
	const explicitGrams = extractExplicitWeightGrams(mealName);
	const weightInfo = getWeightSource(mealName, explicitGrams, data?.totalWeight);

	const items = (Array.isArray(data?.ingredients) ? data.ingredients : []).map(mapEdamamIngredient);

	return {
		mealType,
		mealName,
		explicitGrams,
		weightSource: weightInfo.source,
		calories: Number(calories.toFixed(1)),
		protein: Number(protein.toFixed(1)),
		carbs: Number(carbs.toFixed(1)),
		fat: Number(fat.toFixed(1)),
		grams: weightInfo.grams,
		items,
		source: "edamam",
	};
};

module.exports = {
	analyzeQuickAddText,
};
