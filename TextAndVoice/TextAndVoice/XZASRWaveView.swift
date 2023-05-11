//
//  XZASRWaveView.swift
//  TextAndVoice
//
//  Created by LuckyXYJ on 2023/5/11.
//

import UIKit

class XZASRWaveView: UIView {

    /// 显示数据量
    private var showNums: Int = 60
    
    /// 柱子间隔与柱子比例  spaceWidth : barWidth = spaceAndBarScale : 1
    private var spaceAndBarScale: CGFloat = 1.0
    
    /// 柱子与柱子间隔
    private var barWidth: CGFloat = 0
    private var spaceWidth: CGFloat = 0
    
    /// 上下留白大小
    private let bottomSpace: CGFloat = 0.0
    private let topSpace: CGFloat = 0.0

    var gradientLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        barWidth = frame.size.width / (CGFloat(showNums) * (1 + spaceAndBarScale) - spaceAndBarScale)
        spaceWidth = barWidth * spaceAndBarScale
        
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        
        gradientLayer.colors = [
            UIColor.init(red: 92/255, green: 255/255, blue: 242/255, alpha: 1.0).cgColor,
            UIColor.init(red: 46/255, green: 184/255, blue: 121/255, alpha: 1.0).cgColor,
            UIColor.init(red: 92/255, green: 255/255, blue: 242/255, alpha: 1.0).cgColor,
        ]
        gradientLayer.locations = [0, 0.5, 1]
        self.layer.addSublayer(gradientLayer)
    }
    
    public func changeVoice(amplitudes: [Float]) {
        
        let path = UIBezierPath()
        for (i, amplitude) in amplitudes.enumerated() {
            
            let x = CGFloat(i) * (barWidth + spaceWidth)
            let height = (bounds.height - topSpace - bottomSpace) * CGFloat(amplitude)
            let y = (bounds.height - topSpace - bottomSpace - height) / 2 + topSpace
            let bar = UIBezierPath(rect: CGRect(x: x, y: y, width: barWidth, height: height))
            path.append(bar)
        }
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        gradientLayer.frame = CGRect(x: 0, y: topSpace, width: bounds.width, height: bounds.height - topSpace - bottomSpace)
        gradientLayer.mask = shapeLayer
    }
}
