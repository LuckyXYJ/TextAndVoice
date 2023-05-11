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
import UIKit

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
    
    
    /// 定时器，处理录音一段时间无输入后自动退出
    private var timer: Timer?
    
    /// 已经录制的时间
    private var recordedSeconds: Int = 0
    
    /// 上次转文字回调结果的时间
    private var lastRecordedSeconds: Int = 0
    
    /// 自动关闭录制等待时间
    public let autoStopSeconds: Int = 5
    
    /// 系统权限弹窗只会弹出一次，多次调用无意义浪费时间。每次打开应用最多执行一次
    private var hasOnceRequestPermission: Bool = false
    
    func startRecording() {
        self.start()
    }
    
    func stopRecording() {
        self.delegate?.speakRecognitionAutoEnd()
        releaseEngine()
    }
}

extension XZASRManager {

    private func start() {
        
        // 第一次请求权限
        if !hasOnceRequestPermission {
            self.requestPermission {
                self.start()
            }
            return
        }
        
        guard checkPermission() else {
            print("无权限退出")
            return
        }
        
        initASRManger()
    }

    
    /// 初始化 &  开始录制
    private func initASRManger() {
        
        try? AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        audioEngine = AVAudioEngine()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create recognition request")
        }
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { [weak self] result, error in
            self?.recognitionTaskResult(result: result, error: error)
        })
        
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
        
        self.timeStart()
    }
    
    
    /// 识别结果
    /// - Parameters:
    ///   - result: result description
    ///   - error: error description
    private func recognitionTaskResult(result: SFSpeechRecognitionResult?, error: Error?) {
        
        guard let result = result else {
            if let error = error {
                print("Recognition task error: \(error)")
            } else {
                print("Unknown recognition error")
            }
            self.stopRecording()
            return
        }
        
        if result.isFinal {
            self.stopRecording()
            return
        }
        
        let res = result.transcriptions.last?.formattedString
        self.delegate?.speakRecognitionResult(text: res)
        self.lastRecordedSeconds = self.recordedSeconds
    }
    
    private func releaseEngine() {
        if let inputNode = audioEngine?.inputNode {
            inputNode.removeTap(onBus: 0)
            inputNode.reset()
            audioEngine?.stop()
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()
        }
        recognitionTask = nil
        timeStop()
    }
}

// MARK: 记录时间，实现 x 秒无语音输入自动关闭
extension XZASRManager {
    
    private func timeStart() {
        timeStop()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] timer in
            self?.recordedSeconds += 1
            self?.autoStop()
        })
    }
    
    private func timeStop() {
        timer?.invalidate()
        timer = nil
        recordedSeconds = 0
        lastRecordedSeconds = 0
    }
    
    private func autoStop() {
        if recordedSeconds - lastRecordedSeconds > autoStopSeconds {
            self.stopRecording()
        }
    }
    
}

// MARK: 权限
extension XZASRManager {
    
    // 依次请求权限
    private func requestPermission(_ complete:@escaping (() -> Void)) {
        hasOnceRequestPermission = true
        SFSpeechRecognizer.requestAuthorization { status in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                complete()
            }
        }
    }
    
    
    /// 判断权限
    /// - Returns: 是否有权限
    private func checkPermission() -> Bool {
    
        let authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        let permissionStatus = AVAudioSession.sharedInstance().recordPermission
        
        guard authorizationStatus == .authorized && permissionStatus == .granted else {
            
            if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            return false
        }
        return true
    }
}
