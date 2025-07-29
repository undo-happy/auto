# 테스트 환경 설정 및 데이터 명세

## 1. 테스트 환경 구성

### 1.1 하드웨어 요구사항

#### 기본 테스트 기기
```
주요 테스트 기기:
- iPhone 14 Pro (A16 Bionic, 6GB RAM, 128GB)
- iPhone 13 (A15 Bionic, 4GB RAM, 128GB) 
- iPhone 12 (A14 Bionic, 4GB RAM, 64GB)
- iPad Pro 11" (M2, 8GB RAM, 256GB)

호환성 테스트 기기:
- iPhone SE 3rd (A15 Bionic, 4GB RAM, 64GB) - 최소 요구사항
- iPhone 11 (A13 Bionic, 4GB RAM, 64GB) - 레거시 지원
- iPad Air 5th (M1, 8GB RAM, 64GB)
```

#### 시스템 요구사항
```
iOS 버전:
- iOS 17.0+ (주요 테스트)
- iOS 16.0+ (호환성 테스트) 
- iOS 15.0+ (최소 지원 버전)

저장 공간:
- 테스트용 여유 공간: 최소 8GB
- 모델 파일: 3.2GB
- 테스트 데이터: 2GB
- 시스템 여유 공간: 2GB
```

### 1.2 네트워크 환경

#### 온라인 테스트 환경
```
Wi-Fi 연결:
- 고속: 100Mbps 이상, 지연시간 <20ms
- 일반: 20Mbps, 지연시간 50ms
- 저속: 5Mbps, 지연시간 200ms

모바일 데이터:
- 5G: 50Mbps, 지연시간 20ms
- 4G LTE: 10Mbps, 지연시간 100ms  
- 3G: 1Mbps, 지연시간 500ms
```

#### 오프라인 테스트 환경
```
완전 오프라인:
- 비행기 모드 활성화
- Wi-Fi 및 셀룰러 연결 차단
- 로컬 네트워크 접근 차단

부분 오프라인:
- 인터넷 연결 없음, 로컬 Wi-Fi만 연결
- DNS 차단 상태
- 방화벽으로 외부 연결 차단
```

### 1.3 개발 및 테스트 도구

#### Xcode 및 개발 도구
```
필수 도구:
- Xcode 15.0+
- iOS Simulator
- Instruments (성능 프로파일링)
- Console (로그 모니터링)
- Device Manager

추가 도구:
- Charles Proxy (네트워크 모니터링)
- Network Link Conditioner (네트워크 시뮬레이션)
- TestFlight (베타 테스트 배포)
```

#### 성능 모니터링 도구
```
Instruments 템플릿:
- Time Profiler (CPU 사용률)
- Allocations (메모리 사용량)
- Leaks (메모리 누수)
- Energy Log (배터리 사용량)
- Network (네트워크 트래픽)

서드파티 도구:
- MetricKit (iOS 성능 메트릭)
- Firebase Performance (실시간 성능 모니터링)
- Bugsnag (크래시 리포팅)
```

## 2. 테스트 데이터 세트

### 2.1 텍스트 입력 데이터

#### 한국어 텍스트 데이터
```
카테고리별 테스트 문장:

일상 대화:
- "안녕하세요"
- "오늘 날씨가 어때요?"
- "점심 뭐 먹을까요?"
- "주말 계획이 있나요?"
- "감사합니다"

질문 및 요청:
- "Python 프로그래밍 언어에 대해 설명해주세요"
- "건강한 식단을 위한 조언을 주세요"
- "서울에서 부산까지 가는 방법을 알려주세요"
- "스마트폰 배터리를 오래 쓰는 방법은?"
- "영어 공부에 도움이 되는 앱을 추천해주세요"

긴 문장:
- "인공지능 기술의 발전이 현대 사회에 미치는 영향과 앞으로의 전망에 대해 상세히 분석해주시고, 특히 일자리 변화와 교육 시스템의 변화에 대해서도 언급해주세요"
- "기후 변화가 전 세계적으로 미치는 영향을 경제적, 환경적, 사회적 측면에서 종합적으로 분석하고, 개인과 기업, 정부 차원에서 실천할 수 있는 구체적인 대응 방안을 제시해주세요"

전문 용어:
- "머신러닝과 딥러닝의 차이점을 설명해주세요"
- "블록체인 기술의 작동 원리와 응용 분야는?"
- "양자컴퓨팅이 기존 컴퓨팅과 다른 점은 무엇인가요?"
```

#### 다국어 테스트 데이터
```
영어:
- "Hello, how are you today?"
- "Can you explain machine learning in simple terms?"
- "What are the benefits of renewable energy?"

일본어:
- "こんにちは、元気ですか？"
- "日本の文化について教えてください"
- "おすすめの料理のレシピを教えて"

중국어 (간체):
- "你好，今天天气怎么样？"
- "请介绍一下中国的历史"
- "学习中文的好方法有哪些？"

특수 문자 및 이모지:
- "안녕하세요! 😊 오늘 기분이 좋네요! 🌟"
- "수학 공식: E=mc² ∑∞∫∂∇"
- "특수 기호: ♠♣♥♦★☆※◆▲●■"
```

### 2.2 이미지 테스트 데이터

#### 표준 테스트 이미지
```
객체 인식 테스트:
- animals/ (50장)
  - cat_01.jpg ~ cat_10.jpg
  - dog_01.jpg ~ dog_10.jpg  
  - bird_01.jpg ~ bird_10.jpg
  - etc.

- food/ (50장)
  - korean_food/ (김치찌개, 비빔밥, 불고기 등)
  - western_food/ (파스타, 피자, 햄버거 등)
  - dessert/ (케이크, 아이스크림 등)

- objects/ (50장)
  - furniture/ (의자, 테이블, 소파 등)
  - electronics/ (스마트폰, 노트북, TV 등)
  - vehicles/ (자동차, 자전거, 버스 등)

- scenes/ (50장)
  - nature/ (산, 바다, 숲 등)
  - urban/ (건물, 거리, 공원 등)
  - indoor/ (집, 사무실, 카페 등)
```

#### 품질별 테스트 이미지
```
고품질 이미지:
- 해상도: 4K (3840x2160)
- 파일 크기: 5-10MB
- 포맷: JPEG, PNG, HEIC

일반 품질 이미지:
- 해상도: 1080p (1920x1080) 
- 파일 크기: 1-3MB
- 포맷: JPEG

저품질 이미지:
- 해상도: 480p (640x480)
- 파일 크기: 100-500KB
- 포맷: JPEG (고압축)

문제 이미지:
- 매우 어두운 이미지 (underexposed)
- 매우 밝은 이미지 (overexposed)
- 흔들린 이미지 (motion blur)
- 초점 없는 이미지 (out of focus)
- 손상된 이미지 파일
```

### 2.3 음성 테스트 데이터

#### 음성 녹음 데이터
```
화자별 데이터:
- male_speaker/ (성인 남성)
  - clear_speech/ (명확한 발음)
  - fast_speech/ (빠른 발화)
  - slow_speech/ (느린 발화)
  - whisper/ (속삭임)

- female_speaker/ (성인 여성)
  - clear_speech/
  - fast_speech/
  - slow_speech/
  - whisper/

- child_speaker/ (아동)
  - clear_speech/
  - fast_speech/

환경별 데이터:
- clean_audio/ (조용한 환경)
- noisy_audio/ (배경 소음 있음)
- echo_audio/ (울림 있음)
- outdoor_audio/ (야외 환경)
```

#### 음성 명령 테스트 데이터
```
기본 명령:
- "시작해줘"
- "멈춰"
- "다시 해줘"
- "이전으로"
- "다음으로"

복합 명령:
- "이미지를 분석해줘"
- "음성으로 답변해줘"
- "대화 기록을 보여줘"
- "설정을 열어줘"
- "도움말을 보여줘"

긴 명령:
- "이 사진에 나온 음식의 레시피를 자세히 알려주고 음성으로 읽어줘"
- "오늘 날씨를 확인하고 적절한 옷차림을 추천해줘"
```

### 2.4 비디오 테스트 데이터

#### 비디오 클립 데이터
```
짧은 비디오 (5-15초):
- cooking_demo/ (요리 과정)
- exercise_demo/ (운동 동작)
- tutorial/ (설명 영상)
- daily_life/ (일상 활동)

중간 비디오 (30-60초):
- presentation/ (발표 영상)
- interview/ (인터뷰 클립)
- documentary/ (다큐멘터리 발췌)

해상도별 비디오:
- 4K (3840x2160, 30fps)
- 1080p (1920x1080, 30fps)
- 720p (1280x720, 30fps)
- 480p (640x480, 30fps)

포맷별 비디오:
- MP4 (H.264)
- MOV (HEVC)
- AVI
- WMV
```

## 3. 환경 설정 스크립트

### 3.1 iOS 시뮬레이터 설정

```bash
#!/bin/bash
# iOS 시뮬레이터 환경 설정 스크립트

# 시뮬레이터 생성
xcrun simctl create "iPhone14Pro-Test" "iPhone 14 Pro" "iOS-17-0"
xcrun simctl create "iPhone12-Test" "iPhone 12" "iOS-16-0"

# 네트워크 조건 설정
xcrun simctl create "SlowNetwork-Test" "iPhone 14 Pro" "iOS-17-0"

# 시뮬레이터 부팅
xcrun simctl boot "iPhone14Pro-Test"

# 권한 설정
xcrun simctl privacy "iPhone14Pro-Test" grant camera com.yourcompany.chatbot
xcrun simctl privacy "iPhone14Pro-Test" grant microphone com.yourcompany.chatbot
xcrun simctl privacy "iPhone14Pro-Test" grant speech-recognition com.yourcompany.chatbot

echo "iOS 시뮬레이터 테스트 환경 설정 완료"
```

### 3.2 테스트 데이터 생성 스크립트

```python
#!/usr/bin/env python3
# 테스트 데이터 생성 스크립트

import os
import json
import random
from datetime import datetime, timedelta

def generate_test_conversations():
    """테스트용 대화 데이터 생성"""
    conversations = []
    
    # 기본 대화 패턴
    patterns = [
        {
            "user": "안녕하세요",
            "assistant": "안녕하세요! 무엇을 도와드릴까요?"
        },
        {
            "user": "오늘 날씨가 어때요?",
            "assistant": "죄송하지만 실시간 날씨 정보는 제공할 수 없습니다. 날씨 앱을 확인해보세요."
        },
        {
            "user": "Python 프로그래밍에 대해 설명해주세요",
            "assistant": "Python은 간결하고 읽기 쉬운 문법을 가진 프로그래밍 언어입니다..."
        }
    ]
    
    # 1000개의 테스트 대화 생성
    for i in range(1000):
        pattern = random.choice(patterns)
        conversation = {
            "id": f"test_conv_{i:04d}",
            "timestamp": (datetime.now() - timedelta(days=random.randint(1, 30))).isoformat(),
            "messages": [
                {
                    "role": "user",
                    "content": pattern["user"],
                    "timestamp": datetime.now().isoformat()
                },
                {
                    "role": "assistant", 
                    "content": pattern["assistant"],
                    "timestamp": datetime.now().isoformat()
                }
            ]
        }
        conversations.append(conversation)
    
    return conversations

def create_test_images():
    """테스트용 이미지 메타데이터 생성"""
    import requests
    from PIL import Image
    
    # 테스트 이미지 URL 리스트
    test_images = [
        {"url": "https://picsum.photos/800/600", "filename": "test_image_001.jpg"},
        {"url": "https://picsum.photos/1920/1080", "filename": "test_image_002.jpg"},
        {"url": "https://picsum.photos/400/300", "filename": "test_image_003.jpg"}
    ]
    
    os.makedirs("TestData/Images", exist_ok=True)
    
    for img_data in test_images:
        try:
            response = requests.get(img_data["url"])
            with open(f"TestData/Images/{img_data['filename']}", "wb") as f:
                f.write(response.content)
        except Exception as e:
            print(f"이미지 다운로드 실패: {e}")

def main():
    """메인 테스트 데이터 생성 함수"""
    os.makedirs("TestData", exist_ok=True)
    
    # 대화 데이터 생성
    conversations = generate_test_conversations()
    with open("TestData/test_conversations.json", "w", encoding="utf-8") as f:
        json.dump(conversations, f, ensure_ascii=False, indent=2)
    
    # 이미지 데이터 생성
    create_test_images()
    
    print("테스트 데이터 생성 완료")
    print(f"대화 데이터: {len(conversations)}개")
    print("이미지 데이터: TestData/Images/ 폴더 확인")

if __name__ == "__main__":
    main()
```

### 3.3 성능 테스트 자동화 스크립트

```swift
// PerformanceTestRunner.swift
import XCTest
import Foundation

class PerformanceTestRunner: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testResponseTimePerformance() throws {
        // 응답 시간 성능 테스트
        let testMessages = [
            "안녕하세요",
            "Python에 대해 설명해주세요", 
            "긴 텍스트 질문입니다..."
        ]
        
        for message in testMessages {
            measure {
                sendMessageAndWaitForResponse(message)
            }
        }
    }
    
    func testMemoryUsagePattern() throws {
        // 메모리 사용 패턴 테스트
        let initialMemory = getMemoryUsage()
        
        // 100회 반복 테스트
        for i in 1...100 {
            sendMessageAndWaitForResponse("테스트 메시지 \(i)")
            
            if i % 10 == 0 {
                let currentMemory = getMemoryUsage()
                XCTAssertLessThan(currentMemory - initialMemory, 100_000_000) // 100MB 제한
            }
        }
    }
    
    private func sendMessageAndWaitForResponse(_ message: String) {
        let textField = app.textFields["messageInput"]
        textField.tap()
        textField.typeText(message)
        
        let sendButton = app.buttons["sendButton"]
        sendButton.tap()
        
        // 응답 대기
        let responseText = app.staticTexts.matching(identifier: "aiResponse").element
        let exists = NSPredicate(format: "exists == true")
        expectation(for: exists, evaluatedWith: responseText, handler: nil)
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    private func getMemoryUsage() -> Int {
        // 메모리 사용량 측정 로직
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}
```

## 4. 테스트 실행 가이드

### 4.1 수동 테스트 체크리스트

```markdown
## 기능 테스트 체크리스트

### 기본 기능
- [ ] 앱 시작 및 모델 로딩
- [ ] 텍스트 입력 및 응답
- [ ] 이미지 촬영 및 분석  
- [ ] 음성 입력 및 인식
- [ ] 비디오 업로드 및 분석
- [ ] 멀티모달 입력 조합

### 권한 관리
- [ ] 카메라 권한 요청 및 처리
- [ ] 마이크 권한 요청 및 처리
- [ ] 사진 라이브러리 접근 권한
- [ ] 음성 인식 권한

### 에러 처리
- [ ] 네트워크 오류 시 대응
- [ ] 메모리 부족 시 대응
- [ ] 배터리 부족 시 대응
- [ ] 권한 거부 시 대응

### 성능
- [ ] 응답 시간 2초 이하 (텍스트)
- [ ] 메모리 사용량 안정성
- [ ] 배터리 소모량 적정성
- [ ] UI 응답성 유지
```

### 4.2 자동화 테스트 실행

```bash
#!/bin/bash
# 자동화 테스트 실행 스크립트

echo "오프라인 멀티모달 챗봇 자동화 테스트 시작"

# 단위 테스트 실행
echo "1. 단위 테스트 실행..."
xcodebuild test -project OfflineChatbot.xcodeproj -scheme OfflineChatbot -destination 'platform=iOS Simulator,name=iPhone 14 Pro'

# UI 테스트 실행  
echo "2. UI 테스트 실행..."
xcodebuild test -project OfflineChatbot.xcodeproj -scheme OfflineChatbotUITests -destination 'platform=iOS Simulator,name=iPhone 14 Pro'

# 성능 테스트 실행
echo "3. 성능 테스트 실행..."
xcodebuild test -project OfflineChatbot.xcodeproj -scheme PerformanceTests -destination 'platform=iOS Simulator,name=iPhone 14 Pro'

# 테스트 결과 수집
echo "4. 테스트 결과 수집..."
xcrun xccov view --report --json DerivedData/Build/Logs/Test/*.xcresult > test_coverage.json

echo "자동화 테스트 완료"
echo "결과 파일: test_coverage.json"
```

## 5. 테스트 결과 분석

### 5.1 성능 메트릭 수집

```python
# test_metrics_analyzer.py
import json
import matplotlib.pyplot as plt
import numpy as np

class TestMetricsAnalyzer:
    def __init__(self, metrics_file):
        with open(metrics_file, 'r') as f:
            self.metrics = json.load(f)
    
    def analyze_response_times(self):
        """응답 시간 분석"""
        response_times = self.metrics.get('response_times', [])
        
        avg_time = np.mean(response_times)
        p95_time = np.percentile(response_times, 95)
        p99_time = np.percentile(response_times, 99)
        
        print(f"평균 응답 시간: {avg_time:.2f}초")
        print(f"95th 백분위수: {p95_time:.2f}초")
        print(f"99th 백분위수: {p99_time:.2f}초")
        
        # 히스토그램 생성
        plt.figure(figsize=(10, 6))
        plt.hist(response_times, bins=50, alpha=0.7)
        plt.axvline(x=2.0, color='r', linestyle='--', label='목표 시간 (2초)')
        plt.xlabel('응답 시간 (초)')
        plt.ylabel('빈도')
        plt.title('응답 시간 분포')
        plt.legend()
        plt.savefig('response_time_distribution.png')
        plt.close()
    
    def analyze_memory_usage(self):
        """메모리 사용량 분석"""
        memory_usage = self.metrics.get('memory_usage', [])
        
        max_memory = max(memory_usage)
        avg_memory = np.mean(memory_usage)
        
        print(f"최대 메모리 사용량: {max_memory / 1024 / 1024:.1f}MB")
        print(f"평균 메모리 사용량: {avg_memory / 1024 / 1024:.1f}MB")
        
        # 메모리 사용량 시계열 그래프
        plt.figure(figsize=(12, 6))
        plt.plot(memory_usage)
        plt.axhline(y=1.5*1024*1024*1024, color='r', linestyle='--', label='메모리 제한 (1.5GB)')
        plt.xlabel('시간')
        plt.ylabel('메모리 사용량 (바이트)')
        plt.title('메모리 사용량 추이')
        plt.legend()
        plt.savefig('memory_usage_trend.png')
        plt.close()

# 사용 예시
if __name__ == "__main__":
    analyzer = TestMetricsAnalyzer('test_metrics.json')
    analyzer.analyze_response_times()
    analyzer.analyze_memory_usage()
```

### 5.2 테스트 리포트 생성

```python
# test_report_generator.py
from datetime import datetime
import json

def generate_test_report(test_results):
    """테스트 결과 리포트 생성"""
    
    html_template = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>오프라인 멀티모달 챗봇 테스트 리포트</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .header { background-color: #f0f0f0; padding: 20px; border-radius: 8px; }
            .section { margin: 20px 0; }
            .metric { display: flex; justify-content: space-between; padding: 10px; border-bottom: 1px solid #eee; }
            .pass { color: green; font-weight: bold; }
            .fail { color: red; font-weight: bold; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>테스트 결과 리포트</h1>
            <p>생성 시간: {timestamp}</p>
            <p>테스트 기기: {device}</p>
        </div>
        
        <div class="section">
            <h2>기능 테스트 결과</h2>
            {functional_tests}
        </div>
        
        <div class="section">
            <h2>성능 테스트 결과</h2>
            {performance_tests}
        </div>
        
        <div class="section">
            <h2>요약</h2>
            <p>전체 테스트: {total_tests}개</p>
            <p>성공: <span class="pass">{passed_tests}개</span></p>
            <p>실패: <span class="fail">{failed_tests}개</span></p>
            <p>성공률: {success_rate:.1f}%</p>
        </div>
    </body>
    </html>
    """
    
    # 템플릿 변수 채우기
    report_html = html_template.format(
        timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        device=test_results.get('device', 'Unknown'),
        functional_tests=format_test_results(test_results.get('functional', [])),
        performance_tests=format_performance_results(test_results.get('performance', [])),
        total_tests=test_results.get('total', 0),
        passed_tests=test_results.get('passed', 0),
        failed_tests=test_results.get('failed', 0),
        success_rate=test_results.get('success_rate', 0)
    )
    
    # HTML 파일로 저장
    with open('test_report.html', 'w', encoding='utf-8') as f:
        f.write(report_html)
    
    print("테스트 리포트가 생성되었습니다: test_report.html")
```

이상으로 테스트 데이터 및 환경 설정 명세 작성을 완료했습니다.