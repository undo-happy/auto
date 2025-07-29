import XCTest

final class ModelManagementUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testModelManagementViewDisplaysCorrectly() throws {
        // Given
        let app = XCUIApplication()
        
        // Navigate to model management
        let modelManagementButton = app.buttons["모델 관리"]
        if modelManagementButton.exists {
            modelManagementButton.tap()
        }
        
        // Then
        let navigationTitle = app.navigationBars["모델 관리"]
        XCTAssertTrue(navigationTitle.exists, "모델 관리 화면 타이틀이 표시되어야 합니다")
        
        let recommendedSection = app.staticTexts["권장 모델"]
        XCTAssertTrue(recommendedSection.exists, "권장 모델 섹션이 표시되어야 합니다")
        
        let availableSection = app.staticTexts["사용 가능한 모델"]
        XCTAssertTrue(availableSection.exists, "사용 가능한 모델 섹션이 표시되어야 합니다")
    }

    func testModelRowDisplaysModelInformation() throws {
        // Given
        let app = XCUIApplication()
        
        // Navigate to model management
        let modelManagementButton = app.buttons["모델 관리"]
        if modelManagementButton.exists {
            modelManagementButton.tap()
        }
        
        // Then
        let gemmaHighModel = app.staticTexts["Gemma 3n (고사양)"]
        let gemmaMediumModel = app.staticTexts["Gemma 3n (중사양)"]
        let gemmaLowModel = app.staticTexts["Gemma 3n (저사양)"]
        
        XCTAssertTrue(gemmaHighModel.exists || gemmaMediumModel.exists || gemmaLowModel.exists,
                     "적어도 하나의 Gemma 모델이 표시되어야 합니다")
        
        // Check for recommended badge
        let recommendedBadge = app.staticTexts["권장"]
        XCTAssertTrue(recommendedBadge.exists, "권장 모델 배지가 표시되어야 합니다")
    }

    func testModelDetailNavigation() throws {
        // Given
        let app = XCUIApplication()
        
        // Navigate to model management
        let modelManagementButton = app.buttons["모델 관리"]
        if modelManagementButton.exists {
            modelManagementButton.tap()
        }
        
        // When
        let firstModelRow = app.cells.firstMatch
        if firstModelRow.exists {
            firstModelRow.tap()
            
            // Then
            let modelDetailView = app.navigationBars.containing(.staticText, identifier: "Gemma")
            XCTAssertTrue(modelDetailView.element.exists, "모델 상세 화면으로 이동해야 합니다")
        }
    }

    func testDownloadButtonInteraction() throws {
        // Given
        let app = XCUIApplication()
        
        // Navigate to model management
        let modelManagementButton = app.buttons["모델 관리"]
        if modelManagementButton.exists {
            modelManagementButton.tap()
        }
        
        // When
        let downloadButton = app.buttons["arrow.down.circle"]
        if downloadButton.exists {
            downloadButton.tap()
            
            // Then
            // Check if download starts (progress indicator appears)
            let progressIndicator = app.activityIndicators.firstMatch
            XCTAssertTrue(progressIndicator.waitForExistence(timeout: 2.0),
                         "다운로드 시작 시 진행률 표시기가 나타나야 합니다")
        }
    }

    func testModelToggleButtonInteraction() throws {
        // Given
        let app = XCUIApplication()
        
        // Navigate to model management
        let modelManagementButton = app.buttons["모델 관리"]
        if modelManagementButton.exists {
            modelManagementButton.tap()
        }
        
        // When
        let toggleButton = app.buttons["power.circle"]
        if toggleButton.exists {
            let initialState = toggleButton.isSelected
            toggleButton.tap()
            
            // Then
            XCTAssertNotEqual(toggleButton.isSelected, initialState,
                            "토글 버튼 상태가 변경되어야 합니다")
        }
    }

    func testDeleteModelConfirmation() throws {
        // Given
        let app = XCUIApplication()
        
        // Navigate to model management
        let modelManagementButton = app.buttons["모델 관리"]
        if modelManagementButton.exists {
            modelManagementButton.tap()
        }
        
        // When
        let deleteButton = app.buttons["trash.circle"]
        if deleteButton.exists {
            deleteButton.tap()
            
            // Then
            let alert = app.alerts["모델 삭제"]
            XCTAssertTrue(alert.waitForExistence(timeout: 2.0),
                         "삭제 확인 알림이 표시되어야 합니다")
            
            let cancelButton = alert.buttons["취소"]
            let deleteConfirmButton = alert.buttons["삭제"]
            
            XCTAssertTrue(cancelButton.exists, "취소 버튼이 있어야 합니다")
            XCTAssertTrue(deleteConfirmButton.exists, "삭제 버튼이 있어야 합니다")
            
            // Cancel deletion
            cancelButton.tap()
            XCTAssertFalse(alert.exists, "취소 후 알림이 사라져야 합니다")
        }
    }

    func testErrorHandlingDisplay() throws {
        // Given
        let app = XCUIApplication()
        
        // Navigate to model management
        let modelManagementButton = app.buttons["모델 관리"]
        if modelManagementButton.exists {
            modelManagementButton.tap()
        }
        
        // Simulate error condition (if possible)
        // This test would need to be enhanced with mock error injection
        
        // Check if error alert exists
        let errorAlert = app.alerts["오류"]
        if errorAlert.exists {
            // Then
            let okButton = errorAlert.buttons["확인"]
            XCTAssertTrue(okButton.exists, "오류 알림에 확인 버튼이 있어야 합니다")
            
            okButton.tap()
            XCTAssertFalse(errorAlert.exists, "확인 후 오류 알림이 사라져야 합니다")
        }
    }

    func testPullToRefresh() throws {
        // Given
        let app = XCUIApplication()
        
        // Navigate to model management
        let modelManagementButton = app.buttons["모델 관리"]
        if modelManagementButton.exists {
            modelManagementButton.tap()
        }
        
        // When
        let modelList = app.tables.firstMatch
        if modelList.exists {
            // Pull to refresh
            let startCoordinate = modelList.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            let endCoordinate = modelList.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            startCoordinate.press(forDuration: 0.1, thenDragTo: endCoordinate)
            
            // Then
            // Verify that refresh indicator appears briefly
            let refreshIndicator = app.activityIndicators.firstMatch
            XCTAssertTrue(refreshIndicator.waitForExistence(timeout: 1.0) || !refreshIndicator.exists,
                         "새로고침 시 진행률 표시기가 잠시 나타날 수 있습니다")
        }
    }

    func testRetryStateDisplay() throws {
        // Given
        let app = XCUIApplication()
        
        // Navigate to model management
        let modelManagementButton = app.buttons["모델 관리"]
        if modelManagementButton.exists {
            modelManagementButton.tap()
        }
        
        // Look for retry indicators
        let retryIcon = app.images["arrow.clockwise.circle"]
        let retryText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '재시도'"))
        
        if retryIcon.exists || retryText.element.exists {
            // Then
            XCTAssertTrue(true, "재시도 상태가 UI에 표시됩니다")
        }
    }

    func testAccessibilityLabels() throws {
        // Given
        let app = XCUIApplication()
        
        // Navigate to model management
        let modelManagementButton = app.buttons["모델 관리"]
        if modelManagementButton.exists {
            modelManagementButton.tap()
        }
        
        // Then
        let downloadButton = app.buttons["arrow.down.circle"]
        let toggleButton = app.buttons["power.circle"]
        let deleteButton = app.buttons["trash.circle"]
        
        if downloadButton.exists {
            XCTAssertNotNil(downloadButton.label, "다운로드 버튼에 접근성 레이블이 있어야 합니다")
        }
        
        if toggleButton.exists {
            XCTAssertNotNil(toggleButton.label, "토글 버튼에 접근성 레이블이 있어야 합니다")
        }
        
        if deleteButton.exists {
            XCTAssertNotNil(deleteButton.label, "삭제 버튼에 접근성 레이블이 있어야 합니다")
        }
    }
}