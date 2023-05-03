//
//  TextToVoiceViewController.swift
//  TextAndVoice
//
//  Created by LuckyXYJ on 2023/5/3.
//

import UIKit

class TextToVoiceViewController: UIViewController {

    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var textView: UITextView!
    
    let content = "独立寒秋，湘江北去，橘子洲头。看万山红遍，层林尽染；漫江碧透，百舸争流。鹰击长空，鱼翔浅底，万类霜天竞自由。怅寥廓，问苍茫大地，谁主沉浮？携来百侣曾游，忆往昔峥嵘岁月稠。恰同学少年，风华正茂；书生意气，挥斥方遒。指点江山，激扬文字，粪土当年万户侯。曾记否，到中流击水，浪遏飞舟？"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        textView.text = ""
        // Do any additional setup after loading the view.
    }
    
    @IBAction func startRead(_ sender: Any) {
        
        if XZTTSManager.shared.isSpeaking() {
            button.setTitle("继续阅读", for: .normal)
            XZTTSManager.shared.continueSpeaking()
        } else {
            button.setTitle("暂停阅读", for: .normal)
            XZTTSManager.shared.startRead(content: content, delegate: self)
        }
    }
    
    @IBAction func stopRead(_ sender: Any) {
        XZTTSManager.shared.stopSpeaking()
        button.setTitle("开始阅读", for: .normal)
    }
}

extension TextToVoiceViewController: XZTTSManagerDelegte {

    func textToSpeechWillRead(content: String?) {
        print(content ?? "")
        textView.text = content ?? ""
    }

    func textToSpeechEnd() {
        button.setTitle("开始阅读", for: .normal)
    }
}
