//
//  POIAnnotationView.swift
//  earthlord
//
//  自定义 POI 标注视图
//  根据 POI 类型显示不同图标，根据状态显示不同颜色
//

import UIKit
import MapKit

/// 自定义 POI 标注视图
class POIAnnotationView: MKAnnotationView {

    // MARK: - Static Properties

    /// 复用标识符
    static let reuseIdentifier = "POIAnnotationView"

    // MARK: - UI Components

    /// 图标背景视图
    private let backgroundView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.layer.shadowOpacity = 0.3
        return view
    }()

    /// 图标视图
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        return imageView
    }()

    /// 脉冲动画层（可搜刮时显示）
    private var pulseLayer: CAShapeLayer?

    // MARK: - Properties

    /// POI 标注
    private var poiAnnotation: POIAnnotation? {
        annotation as? POIAnnotation
    }

    // MARK: - Initialization

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }

    // MARK: - Setup

    private func setupViews() {
        // 设置 annotation view 的大小
        frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        centerOffset = CGPoint(x: 0, y: -22)  // 让标注点在底部中心

        // 添加背景视图
        backgroundView.frame = CGRect(x: 2, y: 2, width: 40, height: 40)
        addSubview(backgroundView)

        // 添加图标视图
        iconImageView.frame = CGRect(x: 10, y: 10, width: 24, height: 24)
        addSubview(iconImageView)

        // 允许显示 callout
        canShowCallout = true

        // 设置右侧附件按钮（搜刮按钮）
        rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
    }

    // MARK: - Update

    override func prepareForReuse() {
        super.prepareForReuse()
        stopPulseAnimation()
    }

    /// 配置视图
    func configure(with poiAnnotation: POIAnnotation) {
        // 设置图标
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        iconImageView.image = UIImage(systemName: poiAnnotation.iconName, withConfiguration: iconConfig)

        // 设置背景颜色
        backgroundView.backgroundColor = poiAnnotation.typeColor

        // 设置透明度
        alpha = poiAnnotation.opacity

        // 如果可搜刮，显示脉冲动画
        if poiAnnotation.isLootable && !poiAnnotation.isLooted {
            startPulseAnimation(color: poiAnnotation.typeColor)
        } else {
            stopPulseAnimation()
        }

        // 如果已搜刮，添加已搜刮标记
        if poiAnnotation.isLooted {
            addLootedOverlay()
        } else {
            removeLootedOverlay()
        }
    }

    // MARK: - Pulse Animation

    /// 开始脉冲动画
    private func startPulseAnimation(color: UIColor) {
        // 如果已有动画，先停止
        stopPulseAnimation()

        // 创建脉冲层
        let pulseLayer = CAShapeLayer()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let path = UIBezierPath(arcCenter: center, radius: 25, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        pulseLayer.path = path.cgPath
        pulseLayer.fillColor = color.withAlphaComponent(0.3).cgColor
        pulseLayer.strokeColor = color.cgColor
        pulseLayer.lineWidth = 2
        pulseLayer.opacity = 0

        // 插入到最底层
        layer.insertSublayer(pulseLayer, at: 0)
        self.pulseLayer = pulseLayer

        // 创建动画组
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.8
        scaleAnimation.toValue = 1.5

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.8
        opacityAnimation.toValue = 0

        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [scaleAnimation, opacityAnimation]
        animationGroup.duration = 1.5
        animationGroup.repeatCount = .infinity
        animationGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)

        pulseLayer.add(animationGroup, forKey: "pulse")
    }

    /// 停止脉冲动画
    private func stopPulseAnimation() {
        pulseLayer?.removeAllAnimations()
        pulseLayer?.removeFromSuperlayer()
        pulseLayer = nil
    }

    // MARK: - Looted Overlay

    /// 添加已搜刮覆盖层
    private func addLootedOverlay() {
        // 检查是否已有覆盖层
        if viewWithTag(999) != nil { return }

        let overlayView = UIView(frame: CGRect(x: 2, y: 2, width: 40, height: 40))
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        overlayView.layer.cornerRadius = 20
        overlayView.tag = 999

        // 添加已搜刮图标
        let checkIcon = UIImageView(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        checkIcon.image = UIImage(systemName: "checkmark.circle.fill")
        checkIcon.tintColor = .white
        overlayView.addSubview(checkIcon)

        addSubview(overlayView)
    }

    /// 移除已搜刮覆盖层
    private func removeLootedOverlay() {
        viewWithTag(999)?.removeFromSuperview()
    }
}
