//
//  XZASRManager.swift
//  TextAndVoice
//
//  Created by LuckyXYJ on 2023/5/6.
//

import Foundation
import AVFAudio
import Speech
import AVFoundation
import Accelerate

protocol XZASRManagerDelegate: AnyObject {
    
    /// 实时语音识别结果
    /// - Parameter text: 识别的所有内容
    func speakRecognitionResult(text: String?)
    
    /// 语音识别自动结束 超时结束，异常结束，手动结束
    func speakRecognitionAutoEnd()

}

class XZASRManager {
    
    static let shared = XZASRManager()
    
    weak var delegate: XZASRManagerDelegate?
    var audioEngine: AVAudioEngine?
    var speechRecognizer: SFSpeechRecognizer?
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    
    func startRecording() {
        
        checkPermission()
        
        initEngine()

        guard let inputNode = audioEngine?.inputNode else {
            print("Audio engine has no input node")
            self.stopRecording()
            return
        }
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in

            self?.recognitionRequest?.append(buffer)
        }

        audioEngine?.prepare()

        do {
            try audioEngine?.start()
        } catch {
            print("Error starting audio engine: \(error)")
            self.stopRecording()
        }
    }
    
    func stopRecording() {
        self.delegate?.speakRecognitionAutoEnd()
        releaseEngine()
    }
}

extension XZASRManager {
    
    private func checkPermission() {
        
        SFSpeechRecognizer.requestAuthorization { status in
            if status == .authorized {
                // print("已授权")
            } else {
                // print("未授权")
            }
        }
        
        let permissionStatus = AVAudioSession.sharedInstance().recordPermission
        switch permissionStatus {
        case .granted:
            // print("麦克风授权成功")
            break
        case .denied:
            // print("麦克风授权被拒绝")
            break
        case .undetermined:
            // print("麦克风授权状态未确定")
            break
        default:
            break
        }
    }
    
    private func initEngine() {
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        audioEngine = AVAudioEngine()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error setting up audio session: \(error)")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create recognition request")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { result, error in
            guard let result = result else {
                if let error = error {
                    print("Recognition task error: \(error)")
                } else {
                    print("Unknown recognition error")
                }
                return
            }
            
            let res = result.transcriptions.last?.formattedString
            self.delegate?.speakRecognitionResult(text: res)
            
            print(result.bestTranscription.formattedString)
            
            if result.isFinal {
                // 结束后返回最优结果
                print(result.bestTranscription.formattedString)
                let res = result.bestTranscription.formattedString
                self.delegate?.speakRecognitionResult(text: res)
                self.stopRecording()
            }
        })
    }
    
    private func releaseEngine() {
        if let inputNode = audioEngine?.inputNode {
            inputNode.removeTap(onBus: 0)
            audioEngine?.stop()
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()
        }
        recognitionRequest = nil
        recognitionTask = nil
    }
}
