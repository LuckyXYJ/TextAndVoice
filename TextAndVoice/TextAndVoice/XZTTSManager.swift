//
//  XZTTSManager.swift
//  TextAndVoice
//
//  Created by LuckyXYJ on 2023/5/3.
//

import Foundation
import AVFAudio

protocol XZTTSManagerDelegte: AnyObject {

    /// 即将阅读的内容和之前已读的全部内容
    /// - Parameter content: string
    func textToSpeechWillRead(content: String?)

    /// 阅读完成
    func textToSpeechEnd()
}

class XZTTSManager: NSObject {
    
    static let shared = XZTTSManager()
    
    weak var delegate: XZTTSManagerDelegte?
    
    private var speechSynthesizer: AVSpeechSynthesizer?
    private var readString: String?
    
    func startRead(content: String, delegate: XZTTSManagerDelegte, volume: Float = 1, pitchMultiplier: Float = 1, rate: Float = 0.5) {
        
        self.delegate = delegate
        
        guard content.count > 0 else {
            print("no content !!!")
            return
        }
        
        
        if let _ = speechSynthesizer {
            stopSpeaking()
        }
        
        speechSynthesizer = AVSpeechSynthesizer()
        speechSynthesizer?.delegate = self
        
        readString = content
        
        let utterance = AVSpeechUtterance(string: content)
        
        utterance.pitchMultiplier = pitchMultiplier
        utterance.volume = volume
        utterance.rate = rate
        // 不设置 使用系统默认
        let voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.voice = voice
        speechSynthesizer?.speak(utterance)
    }

    /// 暂停阅读
    func pauseSpeaking() {
        speechSynthesizer?.pauseSpeaking(at: .word)
    }
    
    /// 继续阅读
    func continueSpeaking() {
        speechSynthesizer?.continueSpeaking()
    }

    /// 结束阅读
    func stopSpeaking() {
        speechSynthesizer?.stopSpeaking(at: .word)
        clearResources()
    }
    
    
    /// 是否有存在的阅读器
    /// - Returns: bool
    func isSpeaked() -> Bool {
        if let syn = speechSynthesizer {
            return true
        }
        return false
    }
    
    /// 是否正在阅读
    /// - Returns: bool
    func isPaused() -> Bool {
        guard let syn = speechSynthesizer else {
            return false
        }
        return syn.isPaused
    }
    
    private func clearResources() {
        speechSynthesizer = nil
        readString = nil
    }
}

extension XZTTSManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("start")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        self.clearResources()
        self.delegate?.textToSpeechEnd()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        
        if let content = readString {
            let read = String(content.prefix(characterRange.location + characterRange.length))
            self.delegate?.textToSpeechWillRead(content: read)
        }
    }
}
