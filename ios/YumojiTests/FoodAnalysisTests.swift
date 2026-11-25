import XCTest
@testable import Yumoji

final class FoodAnalysisTests: XCTestCase {
    /// The example response in `docs/api.md`. Keep the two in step.
    private let contractExample = """
    {
      "name": "番茄炒蛋",
      "kcal": 320,
      "intro": "酸甜开胃的国民家常菜，鸡蛋嫩滑，番茄多汁。",
      "is_food": true
    }
    """

    private func decode(_ json: String) throws -> FoodAnalysis {
        try JSONDecoder().decode(FoodAnalysis.self, from: Data(json.utf8))
    }

    func testDecodesTheContractExample() throws {
        let analysis = try decode(contractExample)
        XCTAssertEqual(analysis.name, "番茄炒蛋")
        XCTAssertEqual(analysis.kcal, 320)
        XCTAssertEqual(analysis.intro, "酸甜开胃的国民家常菜，鸡蛋嫩滑，番茄多汁。")
        XCTAssertTrue(analysis.isFood)
        XCTAssertLessThanOrEqual(analysis.intro.count, FoodAnalysis.introLimit)
    }

    func testDecodesNullOrMissingKcal() throws {
        let notFood = try decode("""
        {"name": "键盘", "kcal": null, "intro": "这是一把键盘，不能吃。", "is_food": false}
        """)
        XCTAssertNil(notFood.kcal)
        XCTAssertFalse(notFood.isFood)

        let missing = try decode("""
        {"name": "白开水", "intro": "一杯水。", "is_food": true}
        """)
        XCTAssertNil(missing.kcal)
    }

    func testEncodesWithContractKeys() throws {
        let analysis = FoodAnalysis(name: "米饭", kcal: 230, intro: "一碗白米饭。", isFood: true)
        let data = try JSONEncoder().encode(analysis)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["is_food"] as? Bool, true)
        XCTAssertEqual(object["kcal"] as? Int, 230)
        XCTAssertNil(object["isFood"])
        XCTAssertEqual(try JSONDecoder().decode(FoodAnalysis.self, from: data), analysis)
    }

    func testKcalFormatting() {
        XCTAssertEqual(FoodAnalysis.formatKcal(320), "约 320 千卡")
        XCTAssertEqual(FoodAnalysis.formatKcal(1280), "约 1280 千卡")
        XCTAssertEqual(FoodAnalysis.formatKcal(0), "约 0 千卡")
        XCTAssertEqual(FoodAnalysis.formatKcal(-5), "约 0 千卡")
    }

    func testKcalTextIsHiddenWithoutAnEstimate() {
        let known = FoodAnalysis(name: "番茄炒蛋", kcal: 320, intro: "家常菜。", isFood: true)
        XCTAssertEqual(known.kcalText, "约 320 千卡")

        let unknown = FoodAnalysis(name: "抹茶拿铁", kcal: nil, intro: "一杯拿铁。", isFood: true)
        XCTAssertNil(unknown.kcalText)

        let notFood = FoodAnalysis(name: "键盘", kcal: 0, intro: "不能吃。", isFood: false)
        XCTAssertNil(notFood.kcalText)
    }

    func testDisplayIntroIsCutToTheLimit() {
        let long = String(repeating: "好", count: 60)
        let analysis = FoodAnalysis(name: "测试", kcal: nil, intro: long, isFood: true)
        XCTAssertEqual(analysis.displayIntro.count, FoodAnalysis.introLimit)

        let short = FoodAnalysis(name: "测试", kcal: nil, intro: "刚刚好。", isFood: true)
        XCTAssertEqual(short.displayIntro, "刚刚好。")
    }

    func testMockSamplesRespectTheContract() {
        XCTAssertFalse(MockFoodAnalyzer.samples.isEmpty)
        for sample in MockFoodAnalyzer.samples {
            XCTAssertFalse(sample.name.isEmpty)
            XCTAssertFalse(sample.intro.isEmpty)
            XCTAssertLessThanOrEqual(sample.intro.count, FoodAnalysis.introLimit)
        }
    }
}
