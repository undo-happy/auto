import SwiftUI

public struct SimpleMainView: View {
    @StateObject private var modelDownloader = ModelDownloader()
    @StateObject private var chatViewModel = SimpleChatViewModel()
    @State private var showChat = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 앱 제목
                Text("오프라인 AI 챗봇")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                // MVP 3개 기능
                VStack(spacing: 16) {
                    // 1. AI 다운로드
                    ModelDownloadCard(downloader: modelDownloader)
                    
                    // 2. 채팅 화면으로 이동
                    Button {
                        if modelDownloader.isModelReadyForLoading() {
                            showChat = true
                        }
                    } label: {
                        VStack {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 40))
                                .foregroundColor(modelDownloader.isModelReadyForLoading() ? .blue : .gray)
                            Text("AI와 채팅하기")
                                .font(.headline)
                                .foregroundColor(modelDownloader.isModelReadyForLoading() ? .primary : .secondary)
                            if !modelDownloader.isModelReadyForLoading() {
                                Text("먼저 모델을 다운로드해주세요")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((modelDownloader.isModelReadyForLoading() ? Color.blue : Color.gray).opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(!modelDownloader.isModelReadyForLoading())
                    
                    Spacer()
                }
                .padding()
            }
            .fullScreenCover(isPresented: $showChat) {
                SimpleChatView()
                    .environmentObject(chatViewModel)
                    .onAppear {
                        Task {
                            await chatViewModel.loadModel()
                        }
                    }
            }
        }
    }
}

struct ModelDownloadCard: View {
    @ObservedObject var downloader: ModelDownloader
    @State private var showDownloadComplete = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading) {
                    Text("AI 모델 다운로드")
                        .font(.headline)
                    Text("오프라인에서 사용할 AI 모델을 다운로드합니다")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if downloader.isDownloading {
                ProgressView(value: downloader.downloadProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                Text("다운로드 중... \(Int(downloader.downloadProgress * 100))%")
                    .font(.caption)
            } else if downloader.isModelReadyForLoading() {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("모델 다운로드 완료")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                Text("이제 AI와 채팅할 수 있습니다!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button("모델 다운로드") {
                    Task {
                        await downloader.downloadModel()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}