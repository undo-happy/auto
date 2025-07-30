# Technical Requirements Document (TRD)

## 1. Executive Technical Summary
- **프로젝트 개요**  
  본 프로젝트는 iOS 기기(CPU·GPU)를 활용한 오프라인 멀티모달 챗봇 앱으로, 로컬에 탑재된 Gemma 3n 모델로 텍스트·이미지·음성 입력을 처리하고, 온라인 환경에서는 Upstage Solar Pro 2 API를 호출하여 품질 및 속도를 향상시킵니다. 개인정보는 온디바이스에 암호화 저장하며, Firebase Auth와 Toss Payments를 연동합니다.
- **핵심 기술 스택**  
  Swift 5.7+, SwiftUI, Combine, MVVM, Core ML 3+, Metal Performance Shaders, VisionKit, Apple Speech, Realm DB, Firebase(인증·Crashlytics), Toss Payments, GitHub Actions, SwiftPM
- **주요 기술 목표**  
  - 오프라인 평균 응답 시간 ≤2초  
  - 온라인 전환 시 컨텍스트 손실 0건, BLEU/ROUGE 10%↑  
  - 메모리 6GB 이상 환경에서 추론 오류율 ≤1%  
  - OWASP Mobile Top10 0건
- **핵심 가정**  
  - 대상 iOS 기기는 iOS 15 이상, Apple Silicon 또는 A 시리즈 칩셋  
  - 네트워크 감지 후 API 호출 지연 시간 ≤200ms  
  - 로컬 저장소(Realm) 및 iCloud 백업 권한 획득

---

## 2. Tech Stack

| Category              | Technology / Library          | Reasoning (선택 이유)                                      |
| --------------------- | ----------------------------- | --------------------------------------------------------- |
| 언어 및 런타임         | Swift 5.7+                    | iOS 정식 지원, SwiftUI·Combine 연계 용이                   |
| UI 프레임워크          | SwiftUI                       | iOS Human Interface Guidelines 준수, 다크모드 지원 용이     |
| 상태 관리             | Combine + MVVM                | 반응형 UI 구현, ViewModel 분리로 테스트·유지보수 편의        |
| 온디바이스 ML 엔진      | Core ML 3+ / Metal Performance Shaders | 모델 추론 최적화, GPU · Neural Engine 활용                 |
| 음성 처리             | Apple Speech Framework        | 오프라인 음성 인식 모델 내장, WER 관리 용이                |
| 이미지 처리           | VisionKit + Core ML           | 카메라 통합, 이미지 전처리 및 ML 파이프라인 연동            |
| 로컬 데이터베이스       | Realm DB v10+                 | 경량, 오프라인 데이터 저장·검색 최적화                     |
| 암호화 저장           | Apple Secure Enclave (Keychain) | 사용자 데이터·토큰 안전 저장                                 |
| 인증 및 분석           | Firebase Auth (Google 로그인) / Crashlytics | 소셜 로그인 및 안정성 모니터링 제공                         |
| 결제 연동             | Toss Payments SDK             | 국내 간편 결제 지원                                         |
| API 통신              | RESTful API (URLSession)      | 서버리스 함수(Firebase Functions)로 Solar Pro 2 API 호출 준비 |
| 패키지 관리           | Swift Package Manager         | Monorepo 내 모듈 버전 관리 용이                             |
| CI/CD                | GitHub Actions                | iOS 빌드·테스트·배포 자동화                                |

---

## 3. System Architecture Design

### Top-Level Building Blocks
- **앱 클라이언트 (iOS/macOS 유니버설)**
  - Presentation Layer (SwiftUI View)
  - Domain Layer (비즈니스 로직, Use Case)
  - Data Layer (로컬 Realm, Core ML 추론, 원격 API)
- **온디바이스 추론 엔진**
  - Gemma 3n Core ML 모델 + Quantization 모듈
  - Metal Performance Shaders 최적화
- **원격 API 서버리스 함수**
  - Solar Pro 2 호출 래퍼 (Firebase Functions)
  - 인증 및 결제 트리거 엔드포인트
- **클라우드 서비스**
  - Firebase Auth, Crashlytics
  - Toss Payments 인증·결제

### Top-Level Component Interaction Diagram
```mermaid
graph TD
    U[사용자 (iOS)] -->|입력 요청| A[UI Layer]
    A --> B[Domain Layer]
    B --> C[On-Device ML Engine]
    B --> D[Realm DB]
    B --> E[Remote API (Solar Pro 2)]
    E --> F[Firebase Functions]
    F --> G[Upstage Solar Pro 2]
```
- 사용자가 UI를 통해 텍스트·이미지·음성 입력  
- 도메인 로직이 온디바이스 ML 엔진 또는 로컬 DB 호출  
- 온라인 전환 시 서버리스 함수 경유 Solar Pro 2 API 호출  
- 결과를 도메인 레이어로 전달하여 화면에 렌더링  

### Code Organization & Convention

**도메인 중심 조직 전략**
- **도메인 구분**: Chat, User, Media, Payment, Analytics  
- **레이어 분리**: Presentation → Domain → Data → Infrastructure  
- **기능 모듈화**: 각각의 도메인을 Swift 패키지로 분리  
- **공통 모듈**: Utilities, Extensions, Networking, Models

**모노레포 파일 구조 예시**
```
/
├── apps
│   ├── iOSApp
│   │   ├── Sources
│   │   └── Resources
│   └── MacApp
├── libs
│   ├── Core (Utilities, Extensions)
│   ├── Domain
│   │   ├── Chat
│   │   ├── User
│   │   ├── Media
│   │   └── Payment
│   ├── Data
│   │   ├── Local (Realm)
│   │   └── Remote (API, Firebase)
│   └── UIComponents
├── scripts
│   ├── build.sh
│   └── deploy.sh
├── Package.swift
├── fastlane
│   └── Fastfile
└── .github
    └── workflows
        └── ci.yml
```

### Data Flow & Communication Patterns
- **클라이언트-서버 통신**: URLSession 기반 RESTful 요청/응답  
- **DB 상호작용**: Realm Transaction, Query 및 옵저버 패턴  
- **외부 서비스 연동**: Firebase Functions으로 Solar Pro 2 Proxy  
- **실시간 통신**: 해당 기능 필요 시 Combine 퍼블리셔/구독 활용  
- **데이터 동기화**: iCloud 백업 선택 시 Realm 파일 자동 동기화  

---

## 4. Performance & Optimization Strategy
- 모델 로딩 시 Background Thread & Progress Indicator 제공  
- Metal Performance Shaders를 통한 GPU 연산 최적화  
- Core ML 양자화(4bit) + LoRA Adapter 적용으로 모델 경량화  
- Realm DB Lazy Loading 및 인덱싱으로 검색 성능 보장  

---

## 5. Implementation Roadmap & Milestones

### Phase 1: Foundation (M0~M2)
- **Core Infrastructure**: Monorepo 설정, SwiftPM 패키지 구성, GitHub Actions CI  
- **Essential Features**: Gemma 3n 텍스트 기반 오프라인 대화, 기본 UI  
- **Basic Security**: Keychain/Enclave 암호화, Firebase Auth 연동  
- **개발 환경**: Xcode · Fastlane · TestFlight 배포 기본 설정  
- **Timeline**: 2개월

### Phase 2: Feature Enhancement (M3~M5)
- **Advanced Features**: 이미지·음성 입력 처리, 모달 통합 UI  
- **온라인 전환**: Firebase Functions → Solar Pro 2 API, 컨텍스트 유지  
- **Enhanced Security**: OWASP Mobile Top10 점검, 암호화 강화  
- **Monitoring Implementation**: Crashlytics 대시보드 구성  
- **Timeline**: 3개월

### Phase 3: Scaling & Optimization (M6~M8)
- **Scalability Implementation**: macOS 유니버설 앱, iCloud 백업 최적화  
- **Advanced Integrations**: Toss Payments, 다국어 UI(영어·일본어)  
- **Enterprise Features**: 배터리 세이브 모드, 모델 관리 UI  
- **Compliance & Auditing**: 데이터 삭제·백업 정책 구현  
- **Timeline**: 3개월

---

## 6. Risk Assessment & Mitigation Strategies

### Technical Risk Analysis
- 기술 리스크: 모델 양자화 시 품질 저하 → LoRA 보정 및 A/B 테스트  
- 성능 리스크: 고사양 기기별 메모리 과부하 → 프로파일링 및 동적 스레드 제어  
- 보안 리스크: 키 관리 취약 → Secure Enclave + 정기 감사  
- 통합 리스크: Toss Payments SDK 충돌 → 샌드박스 테스트 및 예비 결제 수단 마련  
- **Mitigation**: 주기적 성능 테스트, 코드 리뷰·정적 분석 자동화

### Project Delivery Risks
- 일정 리스크: iOS 리뷰 지연 → Lite 버전 사전 제출  
- 리소스 리스크: ML 온디바이스 전문성 부족 → 외부 컨설팅 및 사내 교육  
- 품질 리스크: 테스트 커버리지 부족 → XCTest·UI 테스트 자동화 강화  
- 배포 리스크: 인증서·프로비저닝 문제 → Fastlane 자동화 및 롤백 플랜 준비  
- **Contingency**: 예비 모델 서버 연결, 주요 기능 우선순위 조정  

---

*끝*