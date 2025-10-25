//
//  Connect2Backend.swift
//  ReaLink
//
//  Created by douer_lucky on 2025/8/19.
//

import Foundation

struct QuestionAsk: Codable {
    let message: String
}

struct Reply: Codable {
    let reply: String
}

// 修改为异步函数
func sendQuestion() async -> String {
    guard let url = URL(string: "http://127.0.0.1:3000/question") else { return "" }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let question = QuestionAsk(message: "你好，这是 Vision Pro 发来的问题！")
    guard let data = try? JSONEncoder().encode(question) else { return "" }
    request.httpBody = data
    
    do {
        let (responseData, _) = try await URLSession.shared.data(for: request)
        let reply = try JSONDecoder().decode(Reply.self, from: responseData)
        print("服务器回复:", reply.reply)
        return reply.reply
    } catch {
        print("请求错误:", error)
        return ""
    }
}
