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

    /// 波动数组
    func speakRecognitionWave(array: [Float])
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
            
            let analyzer = RealtimeAnalyzer(fftSize: 1024)
            let spectra = analyzer.analyse(with: buffer)
            DispatchQueue.main.async {
                self?.delegate?.speakRecognitionWave(array: spectra.first ?? [])
            }
            
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
    
    func convertToFloatArray(from buffer: AVAudioPCMBuffer) -> [Float] {
        let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
        let channel0 = stride(from: 0, to: buffer.frameLength, by: buffer.stride).map({ channels[0][Int($0)] })
        return channel0
    }
}


class voiceToWave {
    
    private func fft(_ buffer: AVAudioPCMBuffer){
        
        
    }
}

class RealtimeAnalyzer {
    private var fftSize: Int
    private lazy var fftSetup = vDSP_create_fftsetup(vDSP_Length(Int(round(log2(Double(fftSize))))), FFTRadix(kFFTRadix2))
    
    public var frequencyBands: Int = 60 //频带数量
    public var startFrequency: Float = 100 //起始频率
    public var endFrequency: Float = 1800 //截止频率
    
    private lazy var bands: [(lowerFrequency: Float, upperFrequency: Float)] = {
        var bands = [(lowerFrequency: Float, upperFrequency: Float)]()
        //1：根据起止频谱、频带数量确定增长的倍数：2^n
        let n = log2(endFrequency/startFrequency) / Float(frequencyBands)
        var nextBand: (lowerFrequency: Float, upperFrequency: Float) = (startFrequency, 0)
        for i in 1...frequencyBands {
            //2：频带的上频点是下频点的2^n倍
            let highFrequency = nextBand.lowerFrequency * powf(2, n)
            nextBand.upperFrequency = i == frequencyBands ? endFrequency : highFrequency
            bands.append(nextBand)
            nextBand.lowerFrequency = highFrequency
        }
        return bands
    }()
    
    private var spectrumBuffer = [[Float]]()
    public var spectrumSmooth: Float = 0.5 {
        didSet {
            spectrumSmooth = max(0.0, spectrumSmooth)
            spectrumSmooth = min(1.0, spectrumSmooth)
        }
    }

    init(fftSize: Int) {
        self.fftSize = fftSize
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    func analyse(with buffer: AVAudioPCMBuffer) -> [[Float]] {
        let channelsAmplitudes = fft(buffer)
        let aWeights = createFrequencyWeights()
        if spectrumBuffer.count == 0 {
            for _ in 0..<channelsAmplitudes.count {
                spectrumBuffer.append(Array<Float>(repeating: 0, count: bands.count))
            }
        }
        for (index, amplitudes) in channelsAmplitudes.enumerated() {
            let weightedAmplitudes = amplitudes.enumerated().map {(index, element) in
                return element * aWeights[index]
            }
            var spectrum = bands.map {
                findMaxAmplitude(for: $0, in: weightedAmplitudes, with: Float(buffer.format.sampleRate)  / Float(self.fftSize)) * 50
            }
            spectrum = highlightWaveform(spectrum: spectrum)
            
            let zipped = zip(spectrumBuffer[index], spectrum)
            spectrumBuffer[index] = zipped.map { $0.0 * spectrumSmooth + $0.1 * (1 - spectrumSmooth) }
        }
        return spectrumBuffer
    }
    
    private func fft(_ buffer: AVAudioPCMBuffer) -> [[Float]] {
        var amplitudes = [[Float]]()
        guard let floatChannelData = buffer.floatChannelData else { return amplitudes }
        
        //1：抽取buffer中的样本数据
        var channels: UnsafePointer<UnsafeMutablePointer<Float>> = floatChannelData
        let channelCount = Int(buffer.format.channelCount)
        let isInterleaved = buffer.format.isInterleaved
        
        if isInterleaved {
            // deinterleave
            let interleavedData = UnsafeBufferPointer(start: floatChannelData[0], count: self.fftSize * channelCount)
            var channelsTemp : [UnsafeMutablePointer<Float>] = []
            for i in 0..<channelCount {
                var channelData = stride(from: i, to: interleavedData.count, by: channelCount).map{ interleavedData[$0] }
                channelsTemp.append(UnsafeMutablePointer(&channelData))
            }
            channels = UnsafePointer(channelsTemp)
        }
        
        for i in 0..<channelCount {
            
            let channel = channels[i]
            //2: 加汉宁窗
            var window = [Float](repeating: 0, count: Int(fftSize))
            vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
            vDSP_vmul(channel, 1, window, 1, channel, 1, vDSP_Length(fftSize))
            
            //3: 将实数包装成FFT要求的复数fftInOut，既是输入也是输出
            var realp = [Float](repeating: 0.0, count: Int(fftSize / 2))
            var imagp = [Float](repeating: 0.0, count: Int(fftSize / 2))
            var fftInOut = DSPSplitComplex(realp: &realp, imagp: &imagp)
            channel.withMemoryRebound(to: DSPComplex.self, capacity: fftSize) { (typeConvertedTransferBuffer) -> Void in
                vDSP_ctoz(typeConvertedTransferBuffer, 2, &fftInOut, 1, vDSP_Length(fftSize / 2))
            }
            
            //4：执行FFT
            vDSP_fft_zrip(fftSetup!, &fftInOut, 1, vDSP_Length(round(log2(Double(fftSize)))), FFTDirection(FFT_FORWARD));
            
            //5：调整FFT结果，计算振幅
            fftInOut.imagp[0] = 0
            let fftNormFactor = Float(1.0 / (Float(fftSize)))
            vDSP_vsmul(fftInOut.realp, 1, [fftNormFactor], fftInOut.realp, 1, vDSP_Length(fftSize / 2));
            vDSP_vsmul(fftInOut.imagp, 1, [fftNormFactor], fftInOut.imagp, 1, vDSP_Length(fftSize / 2));
            var channelAmplitudes = [Float](repeating: 0.0, count: Int(fftSize / 2))
            vDSP_zvabs(&fftInOut, 1, &channelAmplitudes, 1, vDSP_Length(fftSize / 2));
            channelAmplitudes[0] = channelAmplitudes[0] / 2 //直流分量的振幅需要再除以2
            amplitudes.append(channelAmplitudes)
        }
        return amplitudes
    }
    
    private func findMaxAmplitude(for band:(lowerFrequency: Float, upperFrequency: Float), in amplitudes: [Float], with bandWidth: Float) -> Float {
        let startIndex = Int(round(band.lowerFrequency / bandWidth))
        let endIndex = min(Int(round(band.upperFrequency / bandWidth)), amplitudes.count - 1)
        return amplitudes[startIndex...endIndex].max()!
    }
    
    private func createFrequencyWeights() -> [Float] {
        let Δf = 44100.0 / Float(fftSize)
        let bins = fftSize / 2
        var f = (0..<bins).map { Float($0) * Δf}
        f = f.map { $0 * $0 }
        
        let c1 = powf(12194.217, 2.0)
        let c2 = powf(20.598997, 2.0)
        let c3 = powf(107.65265, 2.0)
        let c4 = powf(737.86223, 2.0)
        
        let num = f.map { c1 * $0 * $0 }
        let den = f.map { ($0 + c2) * sqrtf(($0 + c3) * ($0 + c4)) * ($0 + c1) }
        let weights = num.enumerated().map { (index, ele) in
            return 1.2589 * ele / den[index]
        }
        return weights
    }
    
    private func highlightWaveform(spectrum: [Float]) -> [Float] {
        //1: 定义权重数组，数组中间的5表示自己的权重
        //   可以随意修改，个数需要奇数
        let weights: [Float] = [1, 2, 3, 5, 3, 2, 1]
        let totalWeights = Float(weights.reduce(0, +))
        let startIndex = weights.count / 2
        //2: 开头几个不参与计算
        var averagedSpectrum = Array(spectrum[0..<startIndex])
        for i in startIndex..<spectrum.count - startIndex {
            //3: zip作用: zip([a,b,c], [x,y,z]) -> [(a,x), (b,y), (c,z)]
            let zipped = zip(Array(spectrum[i - startIndex...i + startIndex]), weights)
            let averaged = zipped.map { $0.0 * $0.1 }.reduce(0, +) / totalWeights
            averagedSpectrum.append(averaged)
        }
        //4：末尾几个不参与计算
        averagedSpectrum.append(contentsOf: Array(spectrum.suffix(startIndex)))
        return averagedSpectrum
    }
    
}
