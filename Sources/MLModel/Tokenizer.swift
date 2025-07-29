import Foundation
import MLX
import MLXLLM
import MLXLMCommon

// MARK: - Tokenizer Protocol
public protocol Tokenizer {
    func encode(text: String) -> [Int]
    func decode(tokens: [Int]) -> String
}

// MARK: - Llama Tokenizer Implementation
public class LlamaTokenizer: Tokenizer {
    private let vocabSize: Int
    private let tokenToId: [String: Int]
    private let idToToken: [Int: String]
    private let bosToken: String
    private let eosToken: String
    private let unkToken: String
    private let padToken: String
    
    public init(_ tokenizerPath: URL) throws {
        guard let data = try? Data(contentsOf: tokenizerPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TokenizerError.invalidTokenizerFile
        }
        
        // Parse tokenizer.json
        guard let model = json["model"] as? [String: Any],
              let vocab = model["vocab"] as? [String: Int] else {
            throw TokenizerError.missingVocabulary
        }
        
        self.vocabSize = vocab.count
        self.tokenToId = vocab
        self.idToToken = Dictionary(uniqueKeysWithValues: vocab.map { ($1, $0) })
        
        // Special tokens
        if let addedTokens = json["added_tokens"] as? [[String: Any]] {
            var bosToken = "<s>"
            var eosToken = "</s>"
            var unkToken = "<unk>"
            var padToken = "<pad>"
            
            for tokenInfo in addedTokens {
                if let content = tokenInfo["content"] as? String,
                   let special = tokenInfo["special"] as? Bool, special {
                    switch content {
                    case let token where token.contains("bos"):
                        bosToken = token
                    case let token where token.contains("eos"):
                        eosToken = token
                    case let token where token.contains("unk"):
                        unkToken = token
                    case let token where token.contains("pad"):
                        padToken = token
                    default:
                        break
                    }
                }
            }
            
            self.bosToken = bosToken
            self.eosToken = eosToken
            self.unkToken = unkToken
            self.padToken = padToken
        } else {
            self.bosToken = "<s>"
            self.eosToken = "</s>"
            self.unkToken = "<unk>"
            self.padToken = "<pad>"
        }
    }
    
    public func encode(text: String) -> [Int] {
        // Simple BPE encoding - in production, you'd want a more sophisticated implementation
        var tokens: [Int] = []
        
        // Add BOS token
        if let bosId = tokenToId[bosToken] {
            tokens.append(bosId)
        }
        
        // Tokenize text
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        for word in words {
            // Simple word-level tokenization - in practice, you'd use BPE or SentencePiece
            if let tokenId = tokenToId[word] {
                tokens.append(tokenId)
            } else {
                // Handle unknown words by splitting into characters
                for char in word {
                    let charString = String(char)
                    if let charId = tokenToId[charString] {
                        tokens.append(charId)
                    } else if let unkId = tokenToId[unkToken] {
                        tokens.append(unkId)
                    }
                }
            }
        }
        
        // Add EOS token
        if let eosId = tokenToId[eosToken] {
            tokens.append(eosId)
        }
        
        return tokens
    }
    
    public func decode(tokens: [Int]) -> String {
        var decodedTokens: [String] = []
        
        for tokenId in tokens {
            if let token = idToToken[tokenId] {
                // Skip special tokens in output
                if token != bosToken && token != eosToken && token != padToken {
                    decodedTokens.append(token)
                }
            }
        }
        
        return decodedTokens.joined(separator: " ")
    }
    
    public func getVocabSize() -> Int {
        return vocabSize
    }
    
    public func getBosTokenId() -> Int? {
        return tokenToId[bosToken]
    }
    
    public func getEosTokenId() -> Int? {
        return tokenToId[eosToken]
    }
    
    public func getUnkTokenId() -> Int? {
        return tokenToId[unkToken]
    }
    
    public func getPadTokenId() -> Int? {
        return tokenToId[padToken]
    }
}

// MARK: - Tokenizer Errors
public enum TokenizerError: LocalizedError {
    case invalidTokenizerFile
    case missingVocabulary
    case encodingFailed
    case decodingFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidTokenizerFile:
            return "토크나이저 파일이 유효하지 않습니다."
        case .missingVocabulary:
            return "토크나이저에서 어휘 정보를 찾을 수 없습니다."
        case .encodingFailed:
            return "텍스트 인코딩에 실패했습니다."
        case .decodingFailed:
            return "토큰 디코딩에 실패했습니다."
        }
    }
}

// MARK: - Advanced BPE Tokenizer (for production use)
public class BPETokenizer: Tokenizer {
    private let encoder: [String: Int]
    private let decoder: [Int: String]
    private let bpeRanks: [String: Int]
    private let cache: NSCache<NSString, NSArray>
    
    public init(vocabPath: URL, mergesPath: URL) throws {
        // Load vocabulary
        let vocabData = try Data(contentsOf: vocabPath)
        let vocabJson = try JSONSerialization.jsonObject(with: vocabData) as! [String: Int]
        self.encoder = vocabJson
        self.decoder = Dictionary(uniqueKeysWithValues: vocabJson.map { ($1, $0) })
        
        // Load BPE merges
        let mergesData = try String(contentsOf: mergesPath)
        let mergeLines = mergesData.components(separatedBy: .newlines).dropFirst() // Skip header
        
        var bpeRanks: [String: Int] = [:]
        for (index, line) in mergeLines.enumerated() {
            if !line.isEmpty {
                bpeRanks[line] = index
            }
        }
        self.bpeRanks = bpeRanks
        
        self.cache = NSCache<NSString, NSArray>()
        self.cache.countLimit = 10000
    }
    
    public func encode(text: String) -> [Int] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var tokens: [Int] = []
        
        for word in words {
            let wordTokens = bpe(word: word)
            for token in wordTokens {
                if let tokenId = encoder[token] {
                    tokens.append(tokenId)
                }
            }
        }
        
        return tokens
    }
    
    public func decode(tokens: [Int]) -> String {
        let text = tokens.compactMap { decoder[$0] }.joined()
        return text.replacingOccurrences(of: "</w>", with: " ")
    }
    
    private func bpe(word: String) -> [String] {
        let cacheKey = NSString(string: word)
        if let cached = cache.object(forKey: cacheKey) as? [String] {
            return cached
        }
        
        var word = Array(word.unicodeScalars.map { String($0) })
        if !word.isEmpty {
            word[word.count - 1] += "</w>"
        }
        
        var pairs = getPairs(word: word)
        
        if pairs.isEmpty {
            let result = [word.joined()]
            cache.setObject(result as NSArray, forKey: cacheKey)
            return result
        }
        
        while true {
            guard let bigram = pairs.min(by: { bpeRanks[$0, default: Int.max] < bpeRanks[$1, default: Int.max] }),
                  bpeRanks[bigram] != nil else {
                break
            }
            
            let (first, second) = (bigram.components(separatedBy: " ")[0], bigram.components(separatedBy: " ")[1])
            var newWord: [String] = []
            var i = 0
            
            while i < word.count {
                if let j = word[i...].firstIndex(of: first) {
                    newWord.append(contentsOf: word[i..<word.firstIndex(of: word[j])!])
                    i = word.firstIndex(of: word[j])!
                } else {
                    newWord.append(contentsOf: word[i...])
                    break
                }
                
                if word[i] == first && i < word.count - 1 && word[i + 1] == second {
                    newWord.append(first + second)
                    i += 2
                } else {
                    newWord.append(word[i])
                    i += 1
                }
            }
            
            word = newWord
            if word.count == 1 {
                break
            }
            pairs = getPairs(word: word)
        }
        
        let result = word
        cache.setObject(result as NSArray, forKey: cacheKey)
        return result
    }
    
    private func getPairs(word: [String]) -> Set<String> {
        var pairs = Set<String>()
        var prevChar = word[0]
        
        for char in word.dropFirst() {
            pairs.insert("\(prevChar) \(char)")
            prevChar = char
        }
        
        return pairs
    }
}