//
//  HuaweiCredentials.swift
//  Depresso
//
//  Created by ElAmir Mansour on 11/10/2025.
//

// In Core/AI/HuaweiCredentials.swift
// In Core/AI/HuaweiCredentials.swift
import Foundation

struct HuaweiCredentials {
    // ✅ UPDATED: Use the NEW API Key from the email
    static let apiKey = "4_JENf9g9NVi7_332loZt65qIydiAJCPNHhbx0irqaHtJPkfqcUCpp8tp85SlqOU8QX1lYp4AsvLtKqgx0OXRQ"

    // ✅ UPDATED: Use the NEW Endpoint URL from the PDF guide v2
    static let endpointURL = "https://api-ap-southeast-1.modelarts-maas.com/v1/chat/completions"

    // ✅ UPDATED: Choose ONE of the new model names
    // static let modelName = "deepseek-v3.1" // Option 1: DeepSeek
    
    // qwen is much better since our project based on mainly on text and natural speaking 
    static let modelName = "qwen3-32b"       // Option 2: Qwen (Currently selected)
    // You can switch between these two by commenting/uncommenting the lines above.
}
