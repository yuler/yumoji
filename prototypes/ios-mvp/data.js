// 原型数据，逐项对应 iOS 代码。

// MockFoodAnalyzer.samples（ios/Yumoji/Services/FoodAnalyzing.swift）：
// 和 iOS 一样，识别结果与照片内容无关，随机取一条。
const MOCK_SAMPLES = [
  { name: "番茄炒蛋", kcal: 320, intro: "酸甜开胃的国民家常菜，鸡蛋嫩滑，番茄多汁。", isFood: true },
  { name: "红烧牛肉面", kcal: 650, intro: "浓郁的红烧汤头配上劲道面条，大块牛肉炖得软烂入味，吃完整个人都暖了。", isFood: true },
  { name: "抹茶拿铁", kcal: null, intro: "微苦的抹茶遇上绵密奶泡，清爽不腻。", isFood: true },
];
const MOCK_DELAY = 1500; // MockFoodAnalyzer.delay

// 原型控制里「不是食物」用的结果，对应 is_food = false 的接口返回。
const NOT_FOOD = { name: "一只猫", kcal: null, intro: "看起来是一只正在打盹的橘猫。", isFood: false };

// FoodAnalysis.introLimit
const INTRO_LIMIT = 40;

// StickerStyle（ios/Yumoji/Models/StickerStyle.swift）
const DEFAULT_STYLE = { borderRatio: 0.03, edgeSmoothing: 0.25, marginRatio: 0.02 };
const STYLE_RANGES = { borderRatio: [0, 0.1], edgeSmoothing: [0, 1], marginRatio: [0, 0.1] };

// 样例照片：桌布 + 盘子 + 食物。食物（emoji）就是抠图要找的主体。
// 多个食物时和 VisionSubjectLifter 一样合并成一个主体。
const PHOTOS = [
  { id: "egg", table: ["#f3d9b5", "#d9a46c"], foods: [{ emoji: "🍳", x: 0, y: 0, size: 440 }] },
  { id: "noodle", table: ["#e7c9a8", "#b07d55"], foods: [{ emoji: "🍜", x: 0, y: 10, size: 460 }] },
  { id: "matcha", table: ["#dfe6d2", "#98aa80"], foods: [{ emoji: "🍵", x: 0, y: 0, size: 400 }] },
  { id: "two", table: ["#efd2c4", "#b9806a"], foods: [{ emoji: "🍜", x: -150, y: -60, size: 340 }, { emoji: "🥟", x: 190, y: 150, size: 230 }] },
];
