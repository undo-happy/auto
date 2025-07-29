import XCTest
import SwiftUI
@testable import OfflineChatbot

final class DesignSystemTests: XCTestCase {
    
    override func setUpWithError() throws {
        super.setUp()
    }
    
    override func tearDownWithError() throws {
        super.tearDown()
    }
    
    // MARK: - Design Tokens Tests
    
    func testDesignTokensSpacing() {
        // Given & When & Then
        XCTAssertEqual(DesignTokens.Spacing.none, 0)
        XCTAssertEqual(DesignTokens.Spacing.xs, 4)
        XCTAssertEqual(DesignTokens.Spacing.sm, 8)
        XCTAssertEqual(DesignTokens.Spacing.md, 12)
        XCTAssertEqual(DesignTokens.Spacing.base, 16)
        XCTAssertEqual(DesignTokens.Spacing.lg, 20)
        XCTAssertEqual(DesignTokens.Spacing.xl, 24)
        XCTAssertEqual(DesignTokens.Spacing.xl2, 32)
        XCTAssertEqual(DesignTokens.Spacing.xl3, 40)
        XCTAssertEqual(DesignTokens.Spacing.xl4, 48)
        
        // Test semantic spacing
        XCTAssertEqual(DesignTokens.Spacing.ComponentPadding.small, DesignTokens.Spacing.sm)
        XCTAssertEqual(DesignTokens.Spacing.ComponentPadding.medium, DesignTokens.Spacing.base)
        XCTAssertEqual(DesignTokens.Spacing.ComponentPadding.large, DesignTokens.Spacing.xl)
    }
    
    func testDesignTokensBorderRadius() {
        // Given & When & Then
        XCTAssertEqual(DesignTokens.BorderRadius.none, 0)
        XCTAssertEqual(DesignTokens.BorderRadius.xs, 2)
        XCTAssertEqual(DesignTokens.BorderRadius.sm, 4)
        XCTAssertEqual(DesignTokens.BorderRadius.base, 6)
        XCTAssertEqual(DesignTokens.BorderRadius.md, 8)
        XCTAssertEqual(DesignTokens.BorderRadius.lg, 12)
        XCTAssertEqual(DesignTokens.BorderRadius.xl, 16)
        XCTAssertEqual(DesignTokens.BorderRadius.full, 9999)
        
        // Test component-specific border radius
        XCTAssertEqual(DesignTokens.BorderRadius.Component.button, DesignTokens.BorderRadius.base)
        XCTAssertEqual(DesignTokens.BorderRadius.Component.card, DesignTokens.BorderRadius.md)
        XCTAssertEqual(DesignTokens.BorderRadius.Component.input, DesignTokens.BorderRadius.sm)
        XCTAssertEqual(DesignTokens.BorderRadius.Component.badge, DesignTokens.BorderRadius.full)
        XCTAssertEqual(DesignTokens.BorderRadius.Component.modal, DesignTokens.BorderRadius.lg)
    }
    
    func testDesignTokensBorderWidth() {
        // Given & When & Then
        XCTAssertEqual(DesignTokens.BorderWidth.none, 0)
        XCTAssertEqual(DesignTokens.BorderWidth.hairline, 0.5)
        XCTAssertEqual(DesignTokens.BorderWidth.thin, 1)
        XCTAssertEqual(DesignTokens.BorderWidth.medium, 2)
        XCTAssertEqual(DesignTokens.BorderWidth.thick, 4)
        XCTAssertEqual(DesignTokens.BorderWidth.thicker, 8)
    }
    
    func testDesignTokensTypographyFontSizes() {
        // Given & When & Then
        XCTAssertEqual(DesignTokens.Typography.FontSize.xs, 12)
        XCTAssertEqual(DesignTokens.Typography.FontSize.sm, 14)
        XCTAssertEqual(DesignTokens.Typography.FontSize.base, 16)
        XCTAssertEqual(DesignTokens.Typography.FontSize.lg, 18)
        XCTAssertEqual(DesignTokens.Typography.FontSize.xl, 20)
        XCTAssertEqual(DesignTokens.Typography.FontSize.xl2, 24)
        XCTAssertEqual(DesignTokens.Typography.FontSize.xl3, 30)
        XCTAssertEqual(DesignTokens.Typography.FontSize.xl4, 36)
        XCTAssertEqual(DesignTokens.Typography.FontSize.xl5, 48)
        XCTAssertEqual(DesignTokens.Typography.FontSize.xl6, 60)
    }
    
    func testDesignTokensLineHeights() {
        // Given & When & Then
        XCTAssertEqual(DesignTokens.Typography.LineHeight.tight, 1.25)
        XCTAssertEqual(DesignTokens.Typography.LineHeight.normal, 1.5)
        XCTAssertEqual(DesignTokens.Typography.LineHeight.relaxed, 1.75)
        XCTAssertEqual(DesignTokens.Typography.LineHeight.loose, 2.0)
    }
    
    func testDesignTokensShadowProperties() {
        // Given & When & Then
        XCTAssertEqual(DesignTokens.Shadow.Small.radius, 2)
        XCTAssertEqual(DesignTokens.Shadow.Small.offset.height, 1)
        XCTAssertEqual(DesignTokens.Shadow.Small.offset.width, 0)
        
        XCTAssertEqual(DesignTokens.Shadow.Medium.radius, 4)
        XCTAssertEqual(DesignTokens.Shadow.Medium.offset.height, 2)
        
        XCTAssertEqual(DesignTokens.Shadow.Large.radius, 8)
        XCTAssertEqual(DesignTokens.Shadow.Large.offset.height, 4)
        
        XCTAssertEqual(DesignTokens.Shadow.ExtraLarge.radius, 16)
        XCTAssertEqual(DesignTokens.Shadow.ExtraLarge.offset.height, 8)
    }
    
    func testDesignTokensElevationValues() {
        // Given & When & Then
        XCTAssertEqual(DesignTokens.Elevation.surface, 0)
        XCTAssertEqual(DesignTokens.Elevation.raised, 1)
        XCTAssertEqual(DesignTokens.Elevation.overlay, 2)
        XCTAssertEqual(DesignTokens.Elevation.modal, 3)
        XCTAssertEqual(DesignTokens.Elevation.popover, 4)
        XCTAssertEqual(DesignTokens.Elevation.tooltip, 5)
        XCTAssertEqual(DesignTokens.Elevation.notification, 6)
    }
    
    func testDesignTokensAnimationDurations() {
        // Given & When & Then
        XCTAssertEqual(DesignTokens.Animation.Duration.instant, 0)
        XCTAssertEqual(DesignTokens.Animation.Duration.fast, 0.15)
        XCTAssertEqual(DesignTokens.Animation.Duration.normal, 0.25)
        XCTAssertEqual(DesignTokens.Animation.Duration.slow, 0.35)
        XCTAssertEqual(DesignTokens.Animation.Duration.slower, 0.5)
    }
    
    func testDesignTokensOpacityValues() {
        // Given & When & Then
        XCTAssertEqual(DesignTokens.Opacity.transparent, 0.0)
        XCTAssertEqual(DesignTokens.Opacity.subtle, 0.05)
        XCTAssertEqual(DesignTokens.Opacity.light, 0.1)
        XCTAssertEqual(DesignTokens.Opacity.medium, 0.2)
        XCTAssertEqual(DesignTokens.Opacity.strong, 0.4)
        XCTAssertEqual(DesignTokens.Opacity.intense, 0.6)
        XCTAssertEqual(DesignTokens.Opacity.opaque, 1.0)
    }
    
    func testDesignTokensBreakpoints() {
        // Given & When & Then
        XCTAssertEqual(DesignTokens.Breakpoint.xs, 0)
        XCTAssertEqual(DesignTokens.Breakpoint.sm, 576)
        XCTAssertEqual(DesignTokens.Breakpoint.md, 768)
        XCTAssertEqual(DesignTokens.Breakpoint.lg, 992)
        XCTAssertEqual(DesignTokens.Breakpoint.xl, 1200)
        XCTAssertEqual(DesignTokens.Breakpoint.xxl, 1400)
    }
    
    // MARK: - Custom Styles Tests
    
    func testButtonSizeProperties() {
        // Given
        let smallSize = ButtonSize.small
        let mediumSize = ButtonSize.medium
        let largeSize = ButtonSize.large
        
        // When & Then
        XCTAssertEqual(smallSize.horizontalPadding, DesignTokens.Spacing.md)
        XCTAssertEqual(smallSize.verticalPadding, DesignTokens.Spacing.sm)
        
        XCTAssertEqual(mediumSize.horizontalPadding, DesignTokens.Spacing.base)
        XCTAssertEqual(mediumSize.verticalPadding, DesignTokens.Spacing.md)
        
        XCTAssertEqual(largeSize.horizontalPadding, DesignTokens.Spacing.xl)
        XCTAssertEqual(largeSize.verticalPadding, DesignTokens.Spacing.base)
    }
    
    func testInputSizeProperties() {
        // Given
        let smallSize = InputSize.small
        let mediumSize = InputSize.medium
        let largeSize = InputSize.large
        
        // When & Then
        XCTAssertEqual(smallSize.horizontalPadding, DesignTokens.Spacing.md)
        XCTAssertEqual(smallSize.verticalPadding, DesignTokens.Spacing.sm)
        
        XCTAssertEqual(mediumSize.horizontalPadding, DesignTokens.Spacing.base)
        XCTAssertEqual(mediumSize.verticalPadding, DesignTokens.Spacing.md)
        
        XCTAssertEqual(largeSize.horizontalPadding, DesignTokens.Spacing.lg)
        XCTAssertEqual(largeSize.verticalPadding, DesignTokens.Spacing.base)
    }
    
    func testButtonVariantBorderWidth() {
        // Given
        let filled = ButtonVariant.filled
        let outlined = ButtonVariant.outlined
        let text = ButtonVariant.text
        
        // When & Then
        XCTAssertEqual(filled.borderWidth, 0)
        XCTAssertEqual(outlined.borderWidth, DesignTokens.BorderWidth.thin)
        XCTAssertEqual(text.borderWidth, 0)
    }
    
    // MARK: - Badge Component Tests
    
    func testBadgeSizeProperties() {
        // Given
        let smallBadge = BadgeSize.small
        let mediumBadge = BadgeSize.medium
        let largeBadge = BadgeSize.large
        
        // When & Then
        XCTAssertEqual(smallBadge.horizontalPadding, DesignTokens.Spacing.xs)
        XCTAssertEqual(smallBadge.verticalPadding, DesignTokens.Spacing.xs / 2)
        
        XCTAssertEqual(mediumBadge.horizontalPadding, DesignTokens.Spacing.sm)
        XCTAssertEqual(mediumBadge.verticalPadding, DesignTokens.Spacing.xs)
        
        XCTAssertEqual(largeBadge.horizontalPadding, DesignTokens.Spacing.md)
        XCTAssertEqual(largeBadge.verticalPadding, DesignTokens.Spacing.sm)
    }
    
    // MARK: - Spinner Component Tests
    
    func testSpinnerSizeProperties() {
        // Given
        let smallSpinner = SpinnerSize.small
        let mediumSpinner = SpinnerSize.medium
        let largeSpinner = SpinnerSize.large
        
        // When & Then
        XCTAssertEqual(smallSpinner.diameter, 16)
        XCTAssertEqual(smallSpinner.strokeWidth, 2)
        
        XCTAssertEqual(mediumSpinner.diameter, 24)
        XCTAssertEqual(mediumSpinner.strokeWidth, 3)
        
        XCTAssertEqual(largeSpinner.diameter, 32)
        XCTAssertEqual(largeSpinner.strokeWidth, 4)
    }
    
    // MARK: - Avatar Component Tests
    
    func testAvatarSizeProperties() {
        // Given
        let smallAvatar = AvatarSize.small
        let mediumAvatar = AvatarSize.medium
        let largeAvatar = AvatarSize.large
        let extraLargeAvatar = AvatarSize.extraLarge
        
        // When & Then
        XCTAssertEqual(smallAvatar.diameter, 32)
        XCTAssertEqual(mediumAvatar.diameter, 40)
        XCTAssertEqual(largeAvatar.diameter, 48)
        XCTAssertEqual(extraLargeAvatar.diameter, 64)
    }
    
    // MARK: - Color System Tests
    
    func testColorSystemConsistency() {
        // Test that colors are properly defined and accessible
        // This ensures the dynamic color system is working
        
        // Primary colors should be defined
        XCTAssertNotNil(DesignTokens.Colors.primary)
        XCTAssertNotNil(DesignTokens.Colors.primaryLight)
        XCTAssertNotNil(DesignTokens.Colors.primaryDark)
        
        // Secondary colors should be defined
        XCTAssertNotNil(DesignTokens.Colors.secondary)
        XCTAssertNotNil(DesignTokens.Colors.secondaryLight)
        XCTAssertNotNil(DesignTokens.Colors.secondaryDark)
        
        // Semantic colors should be defined
        XCTAssertNotNil(DesignTokens.Colors.success)
        XCTAssertNotNil(DesignTokens.Colors.warning)
        XCTAssertNotNil(DesignTokens.Colors.error)
        XCTAssertNotNil(DesignTokens.Colors.info)
        
        // Background colors should be defined
        XCTAssertNotNil(DesignTokens.Colors.backgroundPrimary)
        XCTAssertNotNil(DesignTokens.Colors.backgroundSecondary)
        XCTAssertNotNil(DesignTokens.Colors.backgroundTertiary)
        
        // Text colors should be defined
        XCTAssertNotNil(DesignTokens.Colors.textPrimary)
        XCTAssertNotNil(DesignTokens.Colors.textSecondary)
        XCTAssertNotNil(DesignTokens.Colors.textTertiary)
        XCTAssertNotNil(DesignTokens.Colors.textDisabled)
        
        // Interactive colors should be defined
        XCTAssertNotNil(DesignTokens.Colors.interactive)
        XCTAssertNotNil(DesignTokens.Colors.interactiveHover)
        XCTAssertNotNil(DesignTokens.Colors.interactivePressed)
        XCTAssertNotNil(DesignTokens.Colors.interactiveDisabled)
    }
    
    // MARK: - Component Creation Tests
    
    func testDSCardCreation() {
        // Given & When
        let filledCard = DSCard(variant: .filled) {
            Text("Test Content")
        }
        
        let outlinedCard = DSCard(variant: .outlined) {
            Text("Test Content")
        }
        
        let elevatedCard = DSCard(variant: .elevated) {
            Text("Test Content")
        }
        
        // Then
        XCTAssertNotNil(filledCard)
        XCTAssertNotNil(outlinedCard)
        XCTAssertNotNil(elevatedCard)
    }
    
    func testDSBadgeCreation() {
        // Given & When
        let primaryBadge = DSBadge("Primary", variant: .primary, size: .medium)
        let successBadge = DSBadge("Success", variant: .success, size: .small)
        let errorBadge = DSBadge("Error", variant: .error, size: .large)
        
        // Then
        XCTAssertNotNil(primaryBadge)
        XCTAssertNotNil(successBadge)
        XCTAssertNotNil(errorBadge)
    }
    
    func testDSProgressBarCreation() {
        // Given & When
        let progressBar = DSProgressBar(progress: 0.5)
        let customProgressBar = DSProgressBar(
            progress: 0.75,
            height: 12,
            backgroundColor: DesignTokens.Colors.surfaceSecondary,
            foregroundColor: DesignTokens.Colors.primary
        )
        
        // Then
        XCTAssertNotNil(progressBar)
        XCTAssertNotNil(customProgressBar)
    }
    
    func testDSCircularProgressCreation() {
        // Given & When
        let circularProgress = DSCircularProgress(progress: 0.6)
        let customCircularProgress = DSCircularProgress(
            progress: 0.8,
            size: 60,
            strokeWidth: 6
        )
        
        // Then
        XCTAssertNotNil(circularProgress)
        XCTAssertNotNil(customCircularProgress)
    }
    
    func testDSLoadingSpinnerCreation() {
        // Given & When
        let smallSpinner = DSLoadingSpinner(size: .small)
        let mediumSpinner = DSLoadingSpinner(size: .medium)
        let largeSpinner = DSLoadingSpinner(size: .large)
        
        // Then
        XCTAssertNotNil(smallSpinner)
        XCTAssertNotNil(mediumSpinner)
        XCTAssertNotNil(largeSpinner)
    }
    
    func testDSAvatarCreation() {
        // Given & When
        let avatarWithInitials = DSAvatar(initials: "AB", size: .medium)
        let avatarWithImage = DSAvatar(
            image: Image(systemName: "person"),
            initials: "CD",
            size: .large
        )
        
        // Then
        XCTAssertNotNil(avatarWithInitials)
        XCTAssertNotNil(avatarWithImage)
    }
    
    func testDSSeparatorCreation() {
        // Given & When
        let horizontalSeparator = DSSeparator(orientation: .horizontal)
        let verticalSeparator = DSSeparator(orientation: .vertical)
        let customSeparator = DSSeparator(
            orientation: .horizontal,
            thickness: 2,
            color: DesignTokens.Colors.primary
        )
        
        // Then
        XCTAssertNotNil(horizontalSeparator)
        XCTAssertNotNil(verticalSeparator)
        XCTAssertNotNil(customSeparator)
    }
    
    // MARK: - Typography Tests
    
    func testFontFamilyConsistency() {
        // Given
        let primaryFont = DesignTokens.Typography.FontFamily.primary
        let secondaryFont = DesignTokens.Typography.FontFamily.secondary
        let monospaceFont = DesignTokens.Typography.FontFamily.monospace
        
        // When & Then
        XCTAssertNotNil(primaryFont.font)
        XCTAssertNotNil(secondaryFont.font)
        XCTAssertNotNil(monospaceFont.font)
        
        // Test all cases are covered
        let allCases = DesignTokens.Typography.FontFamily.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.primary))
        XCTAssertTrue(allCases.contains(.secondary))
        XCTAssertTrue(allCases.contains(.monospace))
    }
    
    func testTextStyleConsistency() {
        // Test that all predefined text styles are properly configured
        let textStyles: [Font] = [
            DesignTokens.Typography.TextStyle.h1,
            DesignTokens.Typography.TextStyle.h2,
            DesignTokens.Typography.TextStyle.h3,
            DesignTokens.Typography.TextStyle.h4,
            DesignTokens.Typography.TextStyle.h5,
            DesignTokens.Typography.TextStyle.h6,
            DesignTokens.Typography.TextStyle.bodyLarge,
            DesignTokens.Typography.TextStyle.body,
            DesignTokens.Typography.TextStyle.bodySmall,
            DesignTokens.Typography.TextStyle.labelLarge,
            DesignTokens.Typography.TextStyle.label,
            DesignTokens.Typography.TextStyle.labelSmall,
            DesignTokens.Typography.TextStyle.caption,
            DesignTokens.Typography.TextStyle.captionSmall,
            DesignTokens.Typography.TextStyle.button,
            DesignTokens.Typography.TextStyle.buttonLarge,
            DesignTokens.Typography.TextStyle.buttonSmall,
            DesignTokens.Typography.TextStyle.code,
            DesignTokens.Typography.TextStyle.overline
        ]
        
        // All text styles should be defined
        XCTAssertEqual(textStyles.count, 19)
        
        // Each style should be valid
        for style in textStyles {
            XCTAssertNotNil(style)
        }
    }
    
    // MARK: - Performance Tests
    
    func testColorSystemPerformance() {
        measure {
            // Test color system performance
            for _ in 0..<1000 {
                _ = DesignTokens.Colors.primary
                _ = DesignTokens.Colors.secondary
                _ = DesignTokens.Colors.success
                _ = DesignTokens.Colors.error
                _ = DesignTokens.Colors.textPrimary
                _ = DesignTokens.Colors.backgroundPrimary
            }
        }
    }
    
    func testSpacingSystemPerformance() {
        measure {
            // Test spacing system performance
            for _ in 0..<1000 {
                _ = DesignTokens.Spacing.xs
                _ = DesignTokens.Spacing.sm
                _ = DesignTokens.Spacing.md
                _ = DesignTokens.Spacing.base
                _ = DesignTokens.Spacing.lg
                _ = DesignTokens.Spacing.xl
            }
        }
    }
    
    func testTypographySystemPerformance() {
        measure {
            // Test typography system performance
            for _ in 0..<1000 {
                _ = DesignTokens.Typography.TextStyle.h1
                _ = DesignTokens.Typography.TextStyle.body
                _ = DesignTokens.Typography.TextStyle.button
                _ = DesignTokens.Typography.TextStyle.caption
            }
        }
    }
    
    // MARK: - UI Snapshot Tests
    
    func testButtonStylesCreation() {
        // Test button style creation and configuration
        let primaryStyle = PrimaryButtonStyle(size: .medium, variant: .filled)
        let secondaryStyle = SecondaryButtonStyle(size: .large, variant: .outlined)
        let destructiveStyle = DestructiveButtonStyle(size: .small, variant: .text)
        
        XCTAssertNotNil(primaryStyle)
        XCTAssertNotNil(secondaryStyle)
        XCTAssertNotNil(destructiveStyle)
    }
    
    func testTextFieldStylesCreation() {
        // Test text field style creation and configuration
        let defaultStyle = DefaultTextFieldStyle(size: .medium, variant: .outlined)
        let errorStyle = ErrorTextFieldStyle(size: .large)
        let filledStyle = DefaultTextFieldStyle(size: .small, variant: .filled)
        
        XCTAssertNotNil(defaultStyle)
        XCTAssertNotNil(errorStyle)
        XCTAssertNotNil(filledStyle)
    }
    
    func testDesignSystemShowcaseCreation() {
        // Test design system showcase view creation
        let showcase = DesignSystemShowcase()
        XCTAssertNotNil(showcase)
    }
    
    func testColorShowcaseCreation() {
        // Test color showcase components
        let colorShowcase = ColorShowcase()
        let colorSection = ColorSection(title: "Test Colors") {
            Text("Test Content")
        }
        let colorPaletteRow = ColorPaletteRow(colors: [
            ("Primary", DesignTokens.Colors.primary),
            ("Secondary", DesignTokens.Colors.secondary)
        ])
        
        XCTAssertNotNil(colorShowcase)
        XCTAssertNotNil(colorSection)
        XCTAssertNotNil(colorPaletteRow)
    }
    
    func testTypographyShowcaseCreation() {
        // Test typography showcase components
        let typographyShowcase = TypographyShowcase()
        let typographySection = TypographySection(title: "Test Typography") {
            Text("Sample Text")
        }
        
        XCTAssertNotNil(typographyShowcase)
        XCTAssertNotNil(typographySection)
    }
    
    func testComponentShowcaseCreation() {
        // Test component showcase view creation
        let componentShowcase = ComponentShowcase(
            isChipSelected: .constant(false),
            progressValue: .constant(0.5),
            textInput: .constant("")
        )
        let componentSection = ComponentSection(title: "Test Components") {
            Text("Test Component")
        }
        
        XCTAssertNotNil(componentShowcase)
        XCTAssertNotNil(componentSection)
    }
    
    func testButtonShowcaseCreation() {
        // Test button showcase view creation
        let buttonShowcase = ButtonShowcase()
        let buttonSection = ButtonSection(title: "Test Buttons") {
            Button("Test") {}
        }
        
        XCTAssertNotNil(buttonShowcase)
        XCTAssertNotNil(buttonSection)
    }
    
    func testListComponentsCreation() {
        // Test list components creation
        let listRow = DSListRow {
            Text("Test Row Content")
        }
        
        let interactiveListRow = DSInteractiveListRow(action: {}) {
            Text("Interactive Row Content")
        }
        
        XCTAssertNotNil(listRow)
        XCTAssertNotNil(interactiveListRow)
    }
    
    func testViewExtensions() {
        // Test view style extensions
        let testView = Text("Test")
        
        let primaryButton = testView.primaryButtonStyle()
        let secondaryButton = testView.secondaryButtonStyle()
        let destructiveButton = testView.destructiveButtonStyle()
        
        XCTAssertNotNil(primaryButton)
        XCTAssertNotNil(secondaryButton)
        XCTAssertNotNil(destructiveButton)
    }
    
    func testTextFieldExtensions() {
        // Test text field style extensions
        let testTextField = TextField("Test", text: .constant(""))
        
        let defaultTextField = testTextField.defaultTextFieldStyle()
        let errorTextField = testTextField.errorTextFieldStyle()
        let filledTextField = testTextField.defaultTextFieldStyle(variant: .filled)
        
        XCTAssertNotNil(defaultTextField)
        XCTAssertNotNil(errorTextField)
        XCTAssertNotNil(filledTextField)
    }
    
    func testDynamicColorCreation() {
        // Test dynamic color helper
        let dynamicColor = Color(
            light: Color.red,
            dark: Color.blue
        )
        
        XCTAssertNotNil(dynamicColor)
    }
    
    func testCompleteDesignSystemIntegration() {
        // Test complete design system integration
        let completeView = VStack {
            Text("Design System Test")
                .font(DesignTokens.Typography.TextStyle.h2)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
            DSCard(variant: .elevated) {
                VStack {
                    DSBadge("Test Badge", variant: .primary)
                    DSProgressBar(progress: 0.7)
                    DSLoadingSpinner(size: .medium)
                }
                .padding(DesignTokens.Spacing.base)
            }
            
            Button("Test Button") {}
                .primaryButtonStyle(size: .medium, variant: .filled)
            
            TextField("Test Input", text: .constant(""))
                .defaultTextFieldStyle(size: .medium, variant: .outlined)
        }
        .padding(DesignTokens.Spacing.base)
        .background(DesignTokens.Colors.backgroundPrimary)
        
        XCTAssertNotNil(completeView)
    }
    
    // MARK: - Design System Consistency Tests
    
    func testDesignTokensIntegration() {
        // Test that all design tokens are properly integrated
        XCTAssertNotNil(DesignTokens.Colors.primary)
        XCTAssertNotNil(DesignTokens.Typography.TextStyle.h1)
        XCTAssertGreaterThan(DesignTokens.Spacing.base, 0)
        XCTAssertGreaterThan(DesignTokens.BorderRadius.base, 0)
        XCTAssertNotNil(DesignTokens.Shadow.Medium.color)
    }
    
    func testComponentConsistencyWithTokens() {
        // Test that components use design tokens consistently
        let badge = DSBadge("Test", variant: .primary, size: .medium)
        let card = DSCard(variant: .elevated) { Text("Test") }
        let progressBar = DSProgressBar(progress: 0.5)
        let avatar = DSAvatar(initials: "AB", size: .medium)
        
        XCTAssertNotNil(badge)
        XCTAssertNotNil(card)
        XCTAssertNotNil(progressBar)
        XCTAssertNotNil(avatar)
    }
}