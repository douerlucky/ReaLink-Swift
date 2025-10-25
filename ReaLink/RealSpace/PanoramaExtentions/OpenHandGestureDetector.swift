//
//  OpenHandGestureDetector.swift
//  ReaLink
//
//  修改为OK手势检测器 - 更精准，不易误触发
//

import Foundation
import ARKit
import simd

/// OK手势检测器（原摊开手势检测器改良版）
class OpenHandGestureDetector {
    
    // MARK: - 配置参数
    struct DetectionConfig {
        /// OK手势检测的置信度阈值 (0.0 - 1.0)
        static let openHandConfidenceThreshold: Float = 0.7  // 提高阈值避免误触发
        
        /// 拇指食指圆圈检测权重
        static let thumbIndexCircleWeight: Float = 0.4
        
        /// 其他三指伸直检测权重
        static let otherFingersExtendedWeight: Float = 0.3
        
        /// 手势稳定性权重
        static let gestureStabilityWeight: Float = 0.3
        
        /// 拇指食指距离阈值 (形成圆圈) - 米
        static let thumbIndexCircleThreshold: Float = 0.025  // 2.5厘米
        
        /// 拇指食指最大距离 (超过则不是圆圈) - 米
        static let thumbIndexMaxDistance: Float = 0.045     // 4.5厘米
        
        /// 其他手指伸展最小距离阈值 - 米
        static let otherFingerExtensionThreshold: Float = 0.12  // 12厘米
        
        /// 连续检测帧数阈值，防止误触发
        static let consecutiveFramesRequired: Int = 8  // 增加到8帧
        
        /// 手势保持稳定时间阈值
        static let gestureStabilityFrames: Int = 5
    }
    
    // MARK: - 检测状态
    private var leftHandConsecutiveFrames: Int = 0
    private var rightHandConsecutiveFrames: Int = 0
    
    // 添加稳定性检测
    private var leftHandStabilityFrames: Int = 0
    private var rightHandStabilityFrames: Int = 0
    private var lastLeftHandThumbIndexDistance: Float = 0
    private var lastRightHandThumbIndexDistance: Float = 0
    
    // MARK: - 公共接口
    
    /// 检测手势结果（保持原有结构，但现在检测OK手势）
    struct OpenHandDetectionResult {
        let isOpenHand: Bool  // 保持原名，但现在表示OK手势
        let confidence: Float
        let chirality: HandChirality
        
        enum HandChirality {
            case left
            case right
        }
    }
    
    /// 检测左手OK手势（保持原函数名）
    /// - Parameter handAnchor: 左手锚点
    /// - Returns: 检测结果
    func detectLeftHandOpen(_ handAnchor: HandAnchor) -> OpenHandDetectionResult {
        let result = performOKGestureDetection(handAnchor: handAnchor, chirality: .left)
        
        // 连续帧检测逻辑
        if result.isOpenHand {
            leftHandConsecutiveFrames += 1
            
            // 检测手势稳定性
            let currentDistance = getThumbIndexDistance(handAnchor: handAnchor)
            if abs(currentDistance - lastLeftHandThumbIndexDistance) < 0.01 {
                leftHandStabilityFrames += 1
            } else {
                leftHandStabilityFrames = 0
            }
            lastLeftHandThumbIndexDistance = currentDistance
            
        } else {
            leftHandConsecutiveFrames = 0
            leftHandStabilityFrames = 0
        }
        
        let finalIsOpen = leftHandConsecutiveFrames >= DetectionConfig.consecutiveFramesRequired &&
                         leftHandStabilityFrames >= DetectionConfig.gestureStabilityFrames
        
        return OpenHandDetectionResult(
            isOpenHand: finalIsOpen,
            confidence: result.confidence,
            chirality: .left
        )
    }
    
    /// 检测右手OK手势（保持原函数名）
    /// - Parameter handAnchor: 右手锚点
    /// - Returns: 检测结果
    func detectRightHandOpen(_ handAnchor: HandAnchor) -> OpenHandDetectionResult {
        let result = performOKGestureDetection(handAnchor: handAnchor, chirality: .right)
        
        // 连续帧检测逻辑
        if result.isOpenHand {
            rightHandConsecutiveFrames += 1
            
            // 检测手势稳定性
            let currentDistance = getThumbIndexDistance(handAnchor: handAnchor)
            if abs(currentDistance - lastRightHandThumbIndexDistance) < 0.01 {
                rightHandStabilityFrames += 1
            } else {
                rightHandStabilityFrames = 0
            }
            lastRightHandThumbIndexDistance = currentDistance
            
        } else {
            rightHandConsecutiveFrames = 0
            rightHandStabilityFrames = 0
        }
        
        let finalIsOpen = rightHandConsecutiveFrames >= DetectionConfig.consecutiveFramesRequired &&
                         rightHandStabilityFrames >= DetectionConfig.gestureStabilityFrames
        
        return OpenHandDetectionResult(
            isOpenHand: finalIsOpen,
            confidence: result.confidence,
            chirality: .right
        )
    }
    
    /// 重置检测状态
    func resetDetectionState() {
        leftHandConsecutiveFrames = 0
        rightHandConsecutiveFrames = 0
        leftHandStabilityFrames = 0
        rightHandStabilityFrames = 0
        lastLeftHandThumbIndexDistance = 0
        lastRightHandThumbIndexDistance = 0
    }
    
    // MARK: - 核心检测算法
    
    /// 执行OK手势检测的核心算法
    /// - Parameters:
    ///   - handAnchor: 手部锚点
    ///   - chirality: 手的类型（左手/右手）
    /// - Returns: 检测结果
    private func performOKGestureDetection(handAnchor: HandAnchor, chirality: OpenHandDetectionResult.HandChirality) -> OpenHandDetectionResult {
        
        guard let handSkeleton = handAnchor.handSkeleton else {
            return OpenHandDetectionResult(isOpenHand: false, confidence: 0.0, chirality: chirality)
        }
        
        // 计算OK手势评分
        var okScore: Float = 0.0
        
        // 1. 检测拇指和食指是否形成圆圈
        okScore += detectThumbIndexCircle(handSkeleton: handSkeleton)
        
        // 2. 检测其他三个手指是否伸直
        okScore += detectOtherFingersExtended(handSkeleton: handSkeleton)
        
        // 3. 检测手势的整体稳定性
        okScore += detectGestureStability(handSkeleton: handSkeleton)
        
        // 限制评分在0-1范围内
        let confidence = min(max(okScore, 0.0), 1.0)
        let isOKGesture = confidence >= DetectionConfig.openHandConfidenceThreshold
        
        return OpenHandDetectionResult(isOpenHand: isOKGesture, confidence: confidence, chirality: chirality)
    }
    
    /// 检测拇指食指圆圈
    /// - Parameter handSkeleton: 手部骨骼
    /// - Returns: 圆圈评分
    private func detectThumbIndexCircle(handSkeleton: HandSkeleton) -> Float {
        let thumbTip = getJointPosition(handSkeleton: handSkeleton, jointName: .thumbTip)
        let indexTip = getJointPosition(handSkeleton: handSkeleton, jointName: .indexFingerTip)
        
        let distance = simd_distance(thumbTip, indexTip)
        
        // OK手势：拇指食指应该接触或非常接近，但不能太远
        if distance <= DetectionConfig.thumbIndexCircleThreshold {
            // 距离越近，评分越高
            let proximityScore = (DetectionConfig.thumbIndexCircleThreshold - distance) / DetectionConfig.thumbIndexCircleThreshold
            return DetectionConfig.thumbIndexCircleWeight * proximityScore
        } else if distance <= DetectionConfig.thumbIndexMaxDistance {
            // 在可接受范围内，但评分较低
            let distanceScore = (DetectionConfig.thumbIndexMaxDistance - distance) /
                               (DetectionConfig.thumbIndexMaxDistance - DetectionConfig.thumbIndexCircleThreshold)
            return DetectionConfig.thumbIndexCircleWeight * distanceScore * 0.5
        }
        
        return 0.0
    }
    
    /// 检测其他三个手指是否伸直
    /// - Parameter handSkeleton: 手部骨骼
    /// - Returns: 伸直评分
    private func detectOtherFingersExtended(handSkeleton: HandSkeleton) -> Float {
        let wristPosition = getJointPosition(handSkeleton: handSkeleton, jointName: .forearmWrist)
        
        let otherFingerTips: [HandSkeleton.JointName] = [
            .middleFingerTip, .ringFingerTip, .littleFingerTip
        ]
        
        var extendedCount = 0
        var totalExtensionScore: Float = 0.0
        
        for jointName in otherFingerTips {
            let tipPosition = getJointPosition(handSkeleton: handSkeleton, jointName: jointName)
            let distanceToWrist = simd_distance(tipPosition, wristPosition)
            
            // OK手势中，中指、无名指、小指应该伸直，距离手腕较远
            if distanceToWrist > DetectionConfig.otherFingerExtensionThreshold {
                extendedCount += 1
                totalExtensionScore += (distanceToWrist - DetectionConfig.otherFingerExtensionThreshold) / 0.05
            }
        }
        
        // 至少两个手指伸直才算有效的OK手势
        if extendedCount >= 2 {
            let averageScore = totalExtensionScore / Float(otherFingerTips.count)
            return DetectionConfig.otherFingersExtendedWeight * min(averageScore, 1.0)
        }
        
        return 0.0
    }
    
    /// 检测手势稳定性
    /// - Parameter handSkeleton: 手部骨骼
    /// - Returns: 稳定性评分
    private func detectGestureStability(handSkeleton: HandSkeleton) -> Float {
        // 检查手指关节的相对位置是否稳定
        let thumbTip = getJointPosition(handSkeleton: handSkeleton, jointName: .thumbTip)
        let indexTip = getJointPosition(handSkeleton: handSkeleton, jointName: .indexFingerTip)
        let middleTip = getJointPosition(handSkeleton: handSkeleton, jointName: .middleFingerTip)
        
        // 计算手指之间的相对位置稳定性
        let thumbIndexVector = normalize(indexTip - thumbTip)
        let thumbMiddleVector = normalize(middleTip - thumbTip)
        
        // OK手势中，这些向量应该相对稳定
        let vectorStability = dot(thumbIndexVector, thumbMiddleVector)
        
        // 稳定性评分基于向量的一致性
        let stabilityScore = abs(vectorStability) < 0.5 ? 1.0 : (1.0 - abs(vectorStability))
        
        return DetectionConfig.gestureStabilityWeight * stabilityScore
    }
    
    /// 获取拇指食指距离（用于稳定性检测）
    /// - Parameter handAnchor: 手部锚点
    /// - Returns: 距离值
    private func getThumbIndexDistance(handAnchor: HandAnchor) -> Float {
        guard let handSkeleton = handAnchor.handSkeleton else { return 0 }
        
        let thumbTip = getJointPosition(handSkeleton: handSkeleton, jointName: .thumbTip)
        let indexTip = getJointPosition(handSkeleton: handSkeleton, jointName: .indexFingerTip)
        
        return simd_distance(thumbTip, indexTip)
    }
    
    /// 获取关节的3D位置
    /// - Parameters:
    ///   - handSkeleton: 手部骨骼
    ///   - jointName: 关节名称
    /// - Returns: 关节的3D位置
    private func getJointPosition(handSkeleton: HandSkeleton, jointName: HandSkeleton.JointName) -> SIMD3<Float> {
        let joint = handSkeleton.joint(jointName)
        let transform = joint.anchorFromJointTransform
        return SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
}

// MARK: - 调试和日志支持（保持原有接口）
extension OpenHandGestureDetector {
    
    /// 获取详细的检测信息，用于调试
    /// - Parameter handAnchor: 手部锚点
    /// - Returns: 详细检测信息
    func getDetailedDetectionInfo(for handAnchor: HandAnchor, chirality: OpenHandDetectionResult.HandChirality) -> String {
        guard let handSkeleton = handAnchor.handSkeleton else {
            return "❌ 无法获取手部骨骼信息"
        }
        
        let circleScore = detectThumbIndexCircle(handSkeleton: handSkeleton)
        let extensionScore = detectOtherFingersExtended(handSkeleton: handSkeleton)
        let stabilityScore = detectGestureStability(handSkeleton: handSkeleton)
        
        let totalScore = circleScore + extensionScore + stabilityScore
        let confidence = min(max(totalScore, 0.0), 1.0)
        
        return """
        👌 \(chirality == .left ? "左手" : "右手")OK手势检测详情:
        ⭕ 拇指食指圆圈评分: \(String(format: "%.3f", circleScore))
        ✋ 其他手指伸直评分: \(String(format: "%.3f", extensionScore))
        📊 手势稳定性评分: \(String(format: "%.3f", stabilityScore))
        📊 总置信度: \(String(format: "%.3f", confidence))
        ✅ 是否OK手势: \(confidence >= DetectionConfig.openHandConfidenceThreshold ? "是" : "否")
        """
    }
    
    /// 检测OK手势（保持原有接口名称）
    func detectOKGesture(handAnchor: HandAnchor) -> Bool {
        guard let handSkeleton = handAnchor.handSkeleton else {
            return false
        }
        
        // 使用更严格的OK手势检测逻辑
        let circleScore = detectThumbIndexCircle(handSkeleton: handSkeleton)
        let extensionScore = detectOtherFingersExtended(handSkeleton: handSkeleton)
        let stabilityScore = detectGestureStability(handSkeleton: handSkeleton)
        
        let totalScore = circleScore + extensionScore + stabilityScore
        
        // OK手势需要更高的置信度
        return totalScore >= 0.8
    }
}
