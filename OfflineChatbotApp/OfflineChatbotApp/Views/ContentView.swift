import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var showingModelSelection = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                modelSelectionSection
                downloadSection
                Spacer()
                chatNavigationSection
            }
            .padding()
            .navigationTitle("Offline Chatbot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        viewModel.showSettings = true
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView()
            }
            .alert("Alert", isPresented: $viewModel.showAlert) {
                Button("OK") { }
            } message: {
                Text(viewModel.alertMessage)
            }
        }
    }
}

private extension ContentView {
    
    var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("AI Model Downloader")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                Text("Available Space: \(viewModel.availableSpace)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Network: Connected")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }
    
    var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Model")
                    .font(.headline)
                Spacer()
                Button("Change") {
                    showingModelSelection = true
                }
                .font(.caption)
            }
            
            Button(action: {
                showingModelSelection = true
            }) {
                ModelSelectionCard(
                    tier: viewModel.selectedTier,
                    isDownloaded: viewModel.isModelDownloaded
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .confirmationDialog("Select Model", isPresented: $showingModelSelection) {
            ForEach(ModelTier.allCases, id: \.self) { tier in
                Button(tier.displayName) {
                    viewModel.selectedTier = tier
                }
            }
        }
    }
    
    var downloadSection: some View {
        VStack(spacing: 16) {
            switch viewModel.downloadState {
            case .idle:
                if viewModel.isModelDownloaded {
                    modelReadyView
                } else {
                    downloadButton
                }
                
            case .downloading:
                downloadProgressView
                
            case .paused:
                pausedDownloadView
                
            case .completed:
                modelReadyView
                
            case .failed(let error):
                errorView(error)
            }
        }
    }
    
    var downloadButton: some View {
        Button("Download Model") {
            viewModel.startDownload()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }
    
    var downloadProgressView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Text("\(Int(viewModel.downloadProgress * 100))%")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if viewModel.downloadSpeed > 0 {
                        Text("\(formatBytes(viewModel.downloadSpeed))/s")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                ProgressView(value: viewModel.downloadProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(formatBytes(Int64(viewModel.downloadedBytes))) / \(formatBytes(viewModel.totalBytes))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if viewModel.estimatedTimeRemaining > 0 {
                            Text("Time remaining: \(formatTimeInterval(viewModel.estimatedTimeRemaining))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button("Pause") {
                            viewModel.pauseDownload()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Cancel") {
                            viewModel.cancelDownload()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    var pausedDownloadView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Text("Download Paused")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Text("\(Int(viewModel.downloadProgress * 100))%")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                ProgressView(value: viewModel.downloadProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(formatBytes(Int64(viewModel.downloadedBytes))) / \(formatBytes(viewModel.totalBytes))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Tap Resume to continue")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button("Resume") {
                            viewModel.resumeDownload()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button("Cancel") {
                            viewModel.cancelDownload()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    var modelReadyView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("Model Ready")
                    .font(.headline)
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Delete") {
                    viewModel.deleteModel()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.red)
            
            Text("Download Failed")
                .font(.headline)
                .foregroundColor(.red)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                viewModel.startDownload()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    var chatNavigationSection: some View {
        NavigationLink(destination: ChatView()) {
            Label("Start Chatting", systemImage: "message")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isModelDownloaded ? Color.blue : Color.gray)
                .cornerRadius(12)
        }
        .disabled(!viewModel.isModelDownloaded)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        if minutes > 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%dh %dm", hours, remainingMinutes)
        }
        return String(format: "%dm %ds", minutes, seconds)
    }
}

struct ModelSelectionCard: View {
    let tier: ModelTier
    let isDownloaded: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(tier.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(tier.estimatedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            HStack {
                TextField("Type your message...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .disabled(isProcessing)
                
                Button(action: sendMessage) {
                    Image(systemName: isProcessing ? "hourglass" : "paperplane.fill")
                        .foregroundColor(inputText.isEmpty ? .gray : .blue)
                }
                .disabled(inputText.isEmpty || isProcessing)
            }
            .padding()
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if messages.isEmpty {
                addWelcomeMessage()
            }
        }
    }
    
    private func addWelcomeMessage() {
        let welcomeMessage = ChatMessage(
            content: "안녕하세요! 저는 오프라인 AI 챗봇입니다. 무엇을 도와드릴까요?",
            isUser: false,
            timestamp: Date()
        )
        messages.append(welcomeMessage)
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(
            content: inputText,
            isUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        let currentInput = inputText
        inputText = ""
        isProcessing = true
        
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            await MainActor.run {
                let aiResponse = generateResponse(for: currentInput)
                let aiMessage = ChatMessage(
                    content: aiResponse,
                    isUser: false,
                    timestamp: Date()
                )
                messages.append(aiMessage)
                isProcessing = false
            }
        }
    }
    
    private func generateResponse(for input: String) -> String {
        let responses = [
            "흥미로운 질문이네요! 더 자세히 말씀해 주시겠어요?",
            "그것에 대해 생각해보겠습니다. 다른 관점은 어떤가요?",
            "좋은 아이디어입니다! 더 알고 싶은 것이 있나요?",
            "죄송하지만 현재는 기본적인 응답만 가능합니다. 실제 AI 모델이 로드되면 더 자세한 답변을 드릴 수 있습니다.",
            "네, 이해했습니다. 다른 질문이 있으시면 언제든 말씀해 주세요!"
        ]
        
        return responses.randomElement() ?? "죄송합니다. 응답을 생성할 수 없습니다."
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .frame(maxWidth: .infinity * 0.7, alignment: .trailing)
                    
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .padding(12)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(16)
                        .frame(maxWidth: .infinity * 0.7, alignment: .leading)
                    
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section("Storage") {
                    Text("Clear Cache")
                    Text("Model Storage Location")
                }
                
                Section("About") {
                    Text("Version 1.0.0")
                    Text("Offline Chatbot App")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}