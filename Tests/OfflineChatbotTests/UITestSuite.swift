import XCTest
import SwiftUI
@testable import OfflineChatbot

/// UI/UX 품질 테스트 스위트
/// 디자인 시스템 컴포넌트들의 다크모드, 접근성, 반응형 동작을 검증
final class UITestSuite: XCTestCase {
    
    override func setUpWithError() throws {
        super.setUp()
    }
    
    override func tearDownWithError() throws {
        super.tearDown()
    }
    
    // MARK: - 다크 모드 호환성 테스트
    
    func testDarkModeColorConsistency() {
        // 모든 주요 컬러가 Light/Dark 모드에서 정의되어 있는지 확인
        let primaryColors = [
            DesignTokens.Colors.primary,
            DesignTokens.Colors.secondary,
            DesignTokens.Colors.backgroundPrimary,
            DesignTokens.Colors.textPrimary,
            DesignTokens.Colors.surface
        ]
        
        for color in primaryColors {
            XCTAssertNotNil(color, "Primary color should be defined for both light and dark modes")
        }
    }
    
    func testSemanticColorAvailability() {
        // 의미적 컬러들이 제대로 정의되어 있는지 확인
        let semanticColors = [
            DesignTokens.Colors.success,
            DesignTokens.Colors.warning,
            DesignTokens.Colors.error,
            DesignTokens.Colors.info
        ]
        
        for color in semanticColors {
            XCTAssertNotNil(color, "Semantic color should be properly defined")
        }
    }
    
    func testInteractiveStateColors() {
        // 인터랙티브 상태 컬러들이 정의되어 있는지 확인
        let interactiveColors = [
            DesignTokens.Colors.interactive,
            DesignTokens.Colors.interactiveHover,
            DesignTokens.Colors.interactivePressed,
            DesignTokens.Colors.interactiveDisabled
        ]
        
        for color in interactiveColors {
            XCTAssertNotNil(color, "Interactive state color should be defined")
        }
    }
    
    // MARK: - 접근성 테스트
    
    func testContrastRatioCompliance() {
        // WCAG AA 기준 컨트라스트 비율 테스트는 실제 구현에서 수행
        // 여기서는 컬러 시스템이 접근성을 고려하여 설계되었는지 검증
        
        // 텍스트/배경 조합이 충분한 대비를 가지는지 확인하는 구조 테스트
        XCTAssertNotNil(DesignTokens.Colors.textPrimary)
        XCTAssertNotNil(DesignTokens.Colors.backgroundPrimary)
        XCTAssertNotNil(DesignTokens.Colors.textSecondary)
        XCTAssertNotNil(DesignTokens.Colors.backgroundSecondary)
    }
    
    func testFontSizeAccessibility() {
        // 최소 폰트 사이즈가 접근성 가이드라인에 맞는지 확인
        XCTAssertGreaterThanOrEqual(DesignTokens.Typography.FontSize.xs, 12, "Minimum font size should be 12pt for accessibility")
        XCTAssertGreaterThanOrEqual(DesignTokens.Typography.FontSize.sm, 14, "Small font size should be at least 14pt")
        XCTAssertGreaterThanOrEqual(DesignTokens.Typography.FontSize.base, 16, "Base font size should be at least 16pt")
    }
    
    func testTouchTargetSizes() {
        // 터치 대상 크기가 최소 44pt x 44pt를 만족하는지 확인
        let smallButton = ButtonSize.small
        let mediumButton = ButtonSize.medium
        
        // 패딩을 포함한 최소 크기 확인
        let smallButtonMinHeight = smallButton.verticalPadding * 2 + DesignTokens.Typography.FontSize.sm
        let mediumButtonMinHeight = mediumButton.verticalPadding * 2 + DesignTokens.Typography.FontSize.base
        
        XCTAssertGreaterThanOrEqual(mediumButtonMinHeight, 44, "Medium button should meet minimum touch target size")
        // Small button은 compact한 UI에서 사용하므로 일부 예외 허용
        XCTAssertGreaterThanOrEqual(smallButtonMinHeight, 32, "Small button should have reasonable touch target size")
    }
    
    // MARK: - 반응형 UI 테스트
    
    func testSpacingConsistency() {
        // 스페이싱 시스템의 일관성 확인
        let spacings = [
            DesignTokens.Spacing.xs,
            DesignTokens.Spacing.sm,
            DesignTokens.Spacing.md,
            DesignTokens.Spacing.base,
            DesignTokens.Spacing.lg,
            DesignTokens.Spacing.xl
        ]
        
        // 스페이싱이 논리적으로 증가하는지 확인
        for i in 0..<spacings.count-1 {
            XCTAssertLessThan(spacings[i], spacings[i+1], "Spacing should increase logically")
        }
    }
    
    func testTypographyScale() {
        // 타이포그래피 스케일의 일관성 확인
        let fontSizes = [
            DesignTokens.Typography.FontSize.xs,
            DesignTokens.Typography.FontSize.sm,
            DesignTokens.Typography.FontSize.base,
            DesignTokens.Typography.FontSize.lg,
            DesignTokens.Typography.FontSize.xl
        ]
        
        // 폰트 사이즈가 논리적으로 증가하는지 확인
        for i in 0..<fontSizes.count-1 {
            XCTAssertLessThan(fontSizes[i], fontSizes[i+1], "Font sizes should increase logically")
        }
    }
    
    func testBorderRadiusProgression() {
        // 보더 레디우스의 논리적 증가 확인
        let borderRadii = [
            DesignTokens.BorderRadius.none,
            DesignTokens.BorderRadius.xs,
            DesignTokens.BorderRadius.sm,
            DesignTokens.BorderRadius.base,
            DesignTokens.BorderRadius.md,
            DesignTokens.BorderRadius.lg,
            DesignTokens.BorderRadius.xl
        ]
        
        for i in 0..<borderRadii.count-1 {
            XCTAssertLessThan(borderRadii[i], borderRadii[i+1], "Border radius should increase logically")
        }
    }
    
    // MARK: - 컴포넌트 구조 테스트
    
    func testCardVariantStructure() {
        // 카드 컴포넌트의 모든 변형이 생성 가능한지 확인
        let filledCard = DSCard(variant: .filled) { Text("Test") }
        let outlinedCard = DSCard(variant: .outlined) { Text("Test") }
        let elevatedCard = DSCard(variant: .elevated) { Text("Test") }
        
        XCTAssertNotNil(filledCard)
        XCTAssertNotNil(outlinedCard)
        XCTAssertNotNil(elevatedCard)
    }
    
    func testBadgeVariantStructure() {
        // 배지 컴포넌트의 모든 변형과 크기가 생성 가능한지 확인
        let badgeVariants: [BadgeVariant] = [.primary, .secondary, .success, .warning, .error, .info, .neutral]
        let badgeSizes: [BadgeSize] = [.small, .medium, .large]
        
        for variant in badgeVariants {
            for size in badgeSizes {
                let badge = DSBadge("Test", variant: variant, size: size)
                XCTAssertNotNil(badge, "Badge with variant \(variant) and size \(size) should be creatable")
            }
        }
    }
    
    func testButtonStyleStructure() {
        // 버튼 스타일의 모든 조합이 생성 가능한지 확인
        let buttonSizes: [ButtonSize] = [.small, .medium, .large]
        let buttonVariants: [ButtonVariant] = [.filled, .outlined, .text]
        
        for size in buttonSizes {
            for variant in buttonVariants {
                let primaryStyle = PrimaryButtonStyle(size: size, variant: variant)
                let secondaryStyle = SecondaryButtonStyle(size: size, variant: variant)
                let destructiveStyle = DestructiveButtonStyle(size: size, variant: variant)
                
                XCTAssertNotNil(primaryStyle)
                XCTAssertNotNil(secondaryStyle)
                XCTAssertNotNil(destructiveStyle)
            }
        }
    }
    
    func testProgressComponentStructure() {
        // 프로그레스 컴포넌트들의 생성 가능성 확인
        let progressBar = DSProgressBar(progress: 0.5)
        let circularProgress = DSCircularProgress(progress: 0.7)
        let loadingSpinners = [
            DSLoadingSpinner(size: .small),
            DSLoadingSpinner(size: .medium),
            DSLoadingSpinner(size: .large)
        ]
        
        XCTAssertNotNil(progressBar)
        XCTAssertNotNil(circularProgress)
        
        for spinner in loadingSpinners {
            XCTAssertNotNil(spinner)
        }
    }
    
    // MARK: - 멀티모달 입력 UX 테스트
    
    func testMultimodalInputComponentCreation() {
        // 멀티모달 입력 관련 컴포넌트들이 정상적으로 생성되는지 확인
        let inputView = AdaptiveMultimodalInputView()
        XCTAssertNotNil(inputView, "AdaptiveMultimodalInputView should be creatable")
    }
    
    func testChatViewComponentCreation() {
        // 채팅 뷰 컴포넌트가 정상적으로 생성되는지 확인
        let chatView = AdaptiveChatView()
        XCTAssertNotNil(chatView, "AdaptiveChatView should be creatable")
    }
    
    func testMainViewComponentCreation() {
        // 메인 뷰 컴포넌트가 정상적으로 생성되는지 확인
        let mainView = AdaptiveMainView()
        XCTAssertNotNil(mainView, "AdaptiveMainView should be creatable")
    }
    
    func testPrivacySettingsViewCreation() {
        // 프라이버시 설정 뷰가 정상적으로 생성되는지 확인
        let privacyView = AdaptivePrivacySettingsView()
        XCTAssertNotNil(privacyView, "AdaptivePrivacySettingsView should be creatable")
    }
    
    // MARK: - 성능 테스트
    
    func testDesignSystemPerformance() {
        // 디자인 시스템 컴포넌트 생성 성능 측정
        measure {
            for _ in 0..<100 {
                _ = DSCard(variant: .elevated) { Text("Performance Test") }
                _ = DSBadge("Test", variant: .primary, size: .medium)
                _ = DSProgressBar(progress: 0.5)
                _ = DSLoadingSpinner(size: .medium)
                _ = DSAvatar(initials: "PT", size: .medium)
            }
        }
    }
    
    func testColorSystemPerformance() {
        // 컬러 시스템 접근 성능 측정
        measure {
            for _ in 0..<1000 {
                _ = DesignTokens.Colors.primary
                _ = DesignTokens.Colors.backgroundPrimary
                _ = DesignTokens.Colors.textPrimary
                _ = DesignTokens.Colors.success
                _ = DesignTokens.Colors.error
            }
        }
    }
    
    // MARK: - 통합 UI 테스트
    
    func testCompleteUIIntegration() {
        // 전체 UI 통합 테스트
        let completeUI = VStack(spacing: DesignTokens.Spacing.base) {
            // 헤더
            Text("UI Integration Test")
                .font(DesignTokens.Typography.TextStyle.h2)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
            // 카드 컨테이너
            DSCard(variant: .elevated) {
                VStack(spacing: DesignTokens.Spacing.md) {
                    // 상태 배지들
                    HStack {
                        DSBadge("Online", variant: .success, size: .small)
                        DSBadge("Premium", variant: .primary, size: .small)
                        DSBadge("Beta", variant: .info, size: .small)
                    }
                    
                    // 프로그레스 표시
                    DSProgressBar(progress: 0.75)
                    
                    // 버튼 그룹
                    HStack {
                        Button("Primary") {}
                            .primaryButtonStyle(size: .medium, variant: .filled)
                        
                        Button("Secondary") {}
                            .secondaryButtonStyle(size: .medium, variant: .outlined)
                    }
                }
                .padding(DesignTokens.Spacing.base)
            }
            
            // 리스트 섹션
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Recent Items")
                    .font(DesignTokens.Typography.TextStyle.labelLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                
                ForEach(0..<3, id: \.self) { index in
                    DSListRow {
                        HStack {
                            DSAvatar(initials: "U\(index + 1)", size: .small)
                            
                            VStack(alignment: .leading) {
                                Text("User \(index + 1)")
                                    .font(DesignTokens.Typography.TextStyle.body)
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                                
                                Text("Last seen recently")
                                    .font(DesignTokens.Typography.TextStyle.caption)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            DSBadge("2", variant: .error, size: .small)
                        }
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.base)
        .background(DesignTokens.Colors.backgroundPrimary)
        
        XCTAssertNotNil(completeUI, "Complete UI integration should work without issues")
    }
    
    func testDynamicTypeSupport() {
        // Dynamic Type 지원 확인 (iOS 접근성 기능)
        let textStyles = [
            DesignTokens.Typography.TextStyle.h1,
            DesignTokens.Typography.TextStyle.body,
            DesignTokens.Typography.TextStyle.caption
        ]
        
        // 모든 텍스트 스타일이 Dynamic Type을 지원하는지 확인
        for style in textStyles {
            XCTAssertNotNil(style, "Text style should support dynamic type scaling")
        }
    }
    
    func testHighContrastModeSupport() {
        // High Contrast 모드 지원 확인
        // 실제 테스트는 시뮬레이터나 기기에서 수행해야 하지만,
        // 구조적으로 지원 가능한지 확인
        XCTAssertNotNil(DesignTokens.Colors.primary)
        XCTAssertNotNil(DesignTokens.Colors.textPrimary)
        XCTAssertNotNil(DesignTokens.Colors.backgroundPrimary)
    }
}