//
//  VoiceToTextViewController.swift
//  TextAndVoice
//
//  Created by LuckyXYJ on 2023/5/3.
//

import UIKit

class VoiceToTextViewController: UIViewController {
    
    private var oldText: String = ""

    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var speakButton: UIButton!
    
    @IBOutlet var waveBgView: UIView!
    
    var waveView: XZASRWaveView?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        waveView = XZASRWaveView(frame: CGRect(x: 0, y: 0, width: 300, height: 150))
        self.waveBgView.addSubview(waveView!)
    }
    

    @IBAction func speakAction(_ sender: Any) {
        
        if speakButton.titleLabel?.text == "开始说话" {
            XZASRManager.shared.delegate = self
            XZASRManager.shared.startRecording()
            self.oldText = self.textView.text
            speakButton.setTitle("结束说话", for: .normal)
            return
        }
        
        XZASRManager.shared.stopRecording()
        speakButton.setTitle("开始说话", for: .normal)
    }
    
    deinit {
        XZASRManager.shared.stopRecording()
    }
}

extension VoiceToTextViewController: XZASRManagerDelegate {
    
    func speakRecognitionResult(text: String?) {
        self.textView.text = self.oldText + (text ?? "")
    }
    
    func speakRecognitionAutoEnd() {
        speakButton.setTitle("开始说话", for: .normal)
    }
    
    func speakRecognitionWave(array: [Float]) {
        self.waveView?.changeVoice(amplitudes: array)
    }
}
