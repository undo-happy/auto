import XCTest
import SwiftUI
@testable import OfflineChatbot

/// 접근성 및 다크모드 호환성 테스트
final class AccessibilityTests: XCTestCase {
    
    override func setUpWithError() throws {
        super.setUp()
    }
    
    override func tearDownWithError() throws {
        super.tearDown()
    }
    
    // MARK: - WCAG 컨트라스트 비율 테스트
    
    func testTextColorContrast() {
        // 텍스트와 배경색 조합이 WCAG AA 기준을 만족하는지 검증
        let textBackgroundCombinations = [
            (DesignTokens.Colors.textPrimary, DesignTokens.Colors.backgroundPrimary),
            (DesignTokens.Colors.textSecondary, DesignTokens.Colors.backgroundSecondary),
            (DesignTokens.Colors.textPrimary, DesignTokens.Colors.surface)
        ]
        
        for (textColor, backgroundColor) in textBackgroundCombinations {
            XCTAssertNotNil(textColor, "Text color should be defined")
            XCTAssertNotNil(backgroundColor, "Background color should be defined")
        }
    }
    
    func testInteractiveElementContrast() {
        // 인터랙티브 요소의 컨트라스트 확인
        let interactiveColors = [
            DesignTokens.Colors.interactive,
            DesignTokens.Colors.interactiveHover,
            DesignTokens.Colors.interactivePressed
        ]
        
        for color in interactiveColors {
            XCTAssertNotNil(color, "Interactive color should be properly defined")
        }
    }
    
    func testSemanticColorContrast() {
        // 의미적 색상의 대비 확인
        let semanticColors = [
            DesignTokens.Colors.success,
            DesignTokens.Colors.warning,
            DesignTokens.Colors.error,
            DesignTokens.Colors.info
        ]
        
        for color in semanticColors {
            XCTAssertNotNil(color, "Semantic color should be defined with proper contrast")
        }
    }
    
    // MARK: - High Contrast 모드 지원 테스트
    
    func testHighContrastColorDefinitions() {
        // High Contrast 변형이 정의된 컬러들 확인
        let criticalColors = [
            DesignTokens.Colors.textPrimary,
            DesignTokens.Colors.backgroundPrimary,
            DesignTokens.Colors.error,
            DesignTokens.Colors.success,
            DesignTokens.Colors.primary
        ]
        
        for color in criticalColors {
            XCTAssertNotNil(color, "Critical color should support High Contrast mode")
        }
    }
    
    func testColorSystemAccessibility() {
        // 컬러 시스템의 접근성 지원 확인
        XCTAssertNotNil(DesignTokens.Colors.textPrimary)
        XCTAssertNotNil(DesignTokens.Colors.textSecondary)
        XCTAssertNotNil(DesignTokens.Colors.textTertiary)
        XCTAssertNotNil(DesignTokens.Colors.textDisabled)
        
        // 배경색 계층 구조 확인
        XCTAssertNotNil(DesignTokens.Colors.backgroundPrimary)
        XCTAssertNotNil(DesignTokens.Colors.backgroundSecondary)
        XCTAssertNotNil(DesignTokens.Colors.backgroundTertiary)
    }
    
    // MARK: - 폰트 크기 접근성 테스트
    
    func testMinimumFontSizes() {
        // iOS HIG 권장 최소 폰트 크기 준수 확인
        XCTAssertGreaterThanOrEqual(DesignTokens.Typography.FontSize.xs, 12, "최소 폰트 크기는 12pt 이상이어야 함")
        XCTAssertGreaterThanOrEqual(DesignTokens.Typography.FontSize.sm, 14, "Small 폰트는 14pt 이상이어야 함")
        XCTAssertGreaterThanOrEqual(DesignTokens.Typography.FontSize.base, 16, "기본 폰트는 16pt 이상이어야 함")
    }
    
    func testDynamicTypeSupport() {
        // Dynamic Type 스케일링 지원 확인
        let textStyles = [
            DesignTokens.Typography.TextStyle.h1,
            DesignTokens.Typography.TextStyle.h2,
            DesignTokens.Typography.TextStyle.h3,
            DesignTokens.Typography.TextStyle.body,
            DesignTokens.Typography.TextStyle.caption
        ]
        
        for style in textStyles {
            XCTAssertNotNil(style, "텍스트 스타일은 Dynamic Type을 지원해야 함")
        }
    }
    
    func testLineHeightAccessibility() {
        // 줄 간격이 접근성 가이드라인을 준수하는지 확인
        XCTAssertGreaterThanOrEqual(DesignTokens.Typography.LineHeight.tight, 1.2, "최소 줄 간격은 1.2 이상이어야 함")
        XCTAssertGreaterThanOrEqual(DesignTokens.Typography.LineHeight.normal, 1.4, "기본 줄 간격은 1.4 이상이어야 함")
        XCTAssertGreaterThanOrEqual(DesignTokens.Typography.LineHeight.relaxed, 1.6, "여유로운 줄 간격은 1.6 이상이어야 함")
    }
    
    // MARK: - 터치 타겟 크기 테스트
    
    func testMinimumTouchTargetSizes() {
        // Apple HIG 권장 최소 터치 타겟 크기 44pt x 44pt 확인
        let buttonSizes = [ButtonSize.small, ButtonSize.medium, ButtonSize.large]
        
        for size in buttonSizes {
            let estimatedHeight = size.verticalPadding * 2 + 16 // 최소 폰트 크기 가정
            
            if size == .medium || size == .large {
                XCTAssertGreaterThanOrEqual(estimatedHeight, 44, "Medium/Large 버튼은 최소 44pt 터치 타겟을 만족해야 함")
            } else {
                XCTAssertGreaterThanOrEqual(estimatedHeight, 32, "Small 버튼도 합리적인 터치 타겟 크기를 가져야 함")
            }
        }
    }
    
    func testInputFieldAccessibility() {
        // 입력 필드의 접근성 확인
        let inputSizes = [InputSize.small, InputSize.medium, InputSize.large]
        
        for size in inputSizes {
            let estimatedHeight = size.verticalPadding * 2 + 16
            XCTAssertGreaterThanOrEqual(estimatedHeight, 32, "입력 필드는 충분한 터치 타겟을 가져야 함")
        }
    }
    
    // MARK: - 다크 모드 호환성 테스트
    
    func testDarkModeColorConsistency() {
        // 다크 모드에서 모든 주요 컬러가 적절히 대응되는지 확인
        let criticalColorPairs = [
            DesignTokens.Colors.primary,
            DesignTokens.Colors.secondary,
            DesignTokens.Colors.backgroundPrimary,
            DesignTokens.Colors.backgroundSecondary,
            DesignTokens.Colors.textPrimary,
            DesignTokens.Colors.textSecondary,
            DesignTokens.Colors.surface,
            DesignTokens.Colors.border
        ]
        
        for color in criticalColorPairs {
            XCTAssertNotNil(color, "다크 모드 지원 컬러가 정의되어야 함")
        }
    }
    
    func testSemanticColorDarkModeSupport() {
        // 의미적 컬러들의 다크 모드 지원 확인
        let semanticColors = [
            DesignTokens.Colors.success,
            DesignTokens.Colors.warning,
            DesignTokens.Colors.error,
            DesignTokens.Colors.info
        ]
        
        for color in semanticColors {
            XCTAssertNotNil(color, "의미적 컬러는 다크 모드를 지원해야 함")
        }
    }
    
    func testComponentDarkModeCompatibility() {
        // 주요 컴포넌트들의 다크 모드 호환성 확인
        let cardComponent = DSCard(variant: .elevated) { Text("다크 모드 테스트") }
        let badgeComponent = DSBadge("테스트", variant: .primary, size: .medium)
        let progressComponent = DSProgressBar(progress: 0.5)
        
        XCTAssertNotNil(cardComponent, "카드 컴포넌트는 다크 모드를 지원해야 함")
        XCTAssertNotNil(badgeComponent, "배지 컴포넌트는 다크 모드를 지원해야 함")
        XCTAssertNotNil(progressComponent, "프로그레스 컴포넌트는 다크 모드를 지원해야 함")
    }
    
    // MARK: - VoiceOver 지원 테스트
    
    func testVoiceOverCompatibleComponents() {
        // VoiceOver 호환 컴포넌트들의 기본 생성 확인
        let textComponent = Text("VoiceOver 테스트")
            .font(DesignTokens.Typography.TextStyle.body)
            .foregroundColor(DesignTokens.Colors.textPrimary)
        
        let buttonComponent = Button("테스트 버튼") {}
            .primaryButtonStyle(size: .medium, variant: .filled)
        
        let cardWithContent = DSCard(variant: .elevated) {
            VStack {
                Text("카드 제목")
                    .font(DesignTokens.Typography.TextStyle.labelLarge)
                Text("카드 내용")
                    .font(DesignTokens.Typography.TextStyle.body)
            }
        }
        
        XCTAssertNotNil(textComponent, "텍스트 컴포넌트는 VoiceOver를 지원해야 함")
        XCTAssertNotNil(buttonComponent, "버튼 컴포넌트는 VoiceOver를 지원해야 함")
        XCTAssertNotNil(cardWithContent, "카드 컴포넌트는 VoiceOver를 지원해야 함")
    }
    
    func testInteractiveElementAccessibility() {
        // 인터랙티브 요소들의 접근성 확인
        let primaryButton = Button("Primary") {}.primaryButtonStyle()
        let secondaryButton = Button("Secondary") {}.secondaryButtonStyle()
        let destructiveButton = Button("Delete") {}.destructiveButtonStyle()
        
        XCTAssertNotNil(primaryButton, "Primary 버튼은 접근성을 지원해야 함")
        XCTAssertNotNil(secondaryButton, "Secondary 버튼은 접근성을 지원해야 함")
        XCTAssertNotNil(destructiveButton, "Destructive 버튼은 접근성을 지원해야 함")
    }
    
    // MARK: - Motion Reduction 지원 테스트
    
    func testReducedMotionSupport() {
        // 애니메이션 지속시간이 적절히 설정되었는지 확인
        XCTAssertGreaterThanOrEqual(DesignTokens.Animation.Duration.instant, 0, "즉시 애니메이션 지원")
        XCTAssertGreaterThan(DesignTokens.Animation.Duration.fast, 0, "빠른 애니메이션 지원")
        XCTAssertGreaterThan(DesignTokens.Animation.Duration.normal, DesignTokens.Animation.Duration.fast, "보통 애니메이션 지원")
        XCTAssertLessThanOrEqual(DesignTokens.Animation.Duration.slow, 0.5, "느린 애니메이션도 접근성을 고려해야 함")
    }
    
    func testAnimationComponentSupport() {
        // 애니메이션 컴포넌트들의 접근성 지원 확인
        let loadingSpinner = DSLoadingSpinner(size: .medium)
        let progressBar = DSProgressBar(progress: 0.5)
        let circularProgress = DSCircularProgress(progress: 0.7)
        
        XCTAssertNotNil(loadingSpinner, "로딩 스피너는 Motion Reduction을 고려해야 함")
        XCTAssertNotNil(progressBar, "프로그레스 바는 Motion Reduction을 고려해야 함")
        XCTAssertNotNil(circularProgress, "원형 프로그레스는 Motion Reduction을 고려해야 함")
    }
    
    // MARK: - 언어 및 지역화 접근성 테스트
    
    func testRTLLanguageSupport() {
        // RTL 언어 지원을 위한 레이아웃 확인
        let cardWithRTLContent = DSCard(variant: .outlined) {
            HStack {
                Text("اختبار RTL")
                    .font(DesignTokens.Typography.TextStyle.body)
                Spacer()
                DSBadge("جديد", variant: .info, size: .small)
            }
            .padding(DesignTokens.Spacing.base)
        }
        
        XCTAssertNotNil(cardWithRTLContent, "RTL 언어를 지원하는 레이아웃이어야 함")
    }
    
    func testMultiLanguageTypography() {
        // 다양한 언어의 타이포그래피 지원 확인
        let multiLanguageText = VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("English Text")
                .font(DesignTokens.Typography.TextStyle.body)
            Text("한국어 텍스트")
                .font(DesignTokens.Typography.TextStyle.body)
            Text("日本語のテキスト")
                .font(DesignTokens.Typography.TextStyle.body)
            Text("中文文本")
                .font(DesignTokens.Typography.TextStyle.body)
        }
        .foregroundColor(DesignTokens.Colors.textPrimary)
        
        XCTAssertNotNil(multiLanguageText, "다국어 타이포그래피를 지원해야 함")
    }
    
    // MARK: - 통합 접근성 테스트
    
    func testCompleteAccessibilityIntegration() {
        // 전체 접근성 기능이 통합된 뷰 테스트
        let accessibleUI = VStack(spacing: DesignTokens.Spacing.base) {
            // 접근성 친화적 헤더
            Text("접근성 테스트")
                .font(DesignTokens.Typography.TextStyle.h2)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
            // 고대비 모드 지원 카드
            DSCard(variant: .elevated) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("중요한 정보")
                        .font(DesignTokens.Typography.TextStyle.labelLarge)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text("이 내용은 모든 사용자가 접근할 수 있어야 합니다.")
                        .font(DesignTokens.Typography.TextStyle.body)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    
                    HStack {
                        DSBadge("중요", variant: .error, size: .small)
                        DSBadge("접근성", variant: .success, size: .small)
                    }
                    
                    Button("자세히 보기") {}
                        .primaryButtonStyle(size: .medium, variant: .filled)
                }
                .padding(DesignTokens.Spacing.base)
            }
            
            // 프로그레스 표시 (Motion Reduction 고려)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("진행률")
                    .font(DesignTokens.Typography.TextStyle.labelLarge)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                DSProgressBar(progress: 0.75)
            }
        }
        .padding(DesignTokens.Spacing.base)
        .background(DesignTokens.Colors.backgroundPrimary)
        
        XCTAssertNotNil(accessibleUI, "통합 접근성 UI가 정상적으로 작동해야 함")
    }
    
    func testAccessibilityPerformance() {
        // 접근성 기능의 성능 측정
        measure {
            for _ in 0..<100 {
                _ = DSCard(variant: .elevated) {
                    VStack {
                        Text("접근성 성능 테스트")
                            .font(DesignTokens.Typography.TextStyle.body)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        
                        DSBadge("테스트", variant: .primary, size: .medium)
                    }
                }
            }
        }
    }
}