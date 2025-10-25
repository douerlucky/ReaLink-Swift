/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A system to update an entity's transform in real time.
*/

// 导入必要的框架
import SwiftUI        // 用于构建用户界面
import RealityKit     // 用于增强现实和3D渲染

/// A component to attach to an entity that updates over time.
/// 这是一个可以附加到实体上的组件，用于随时间更新实体
struct ClosureComponent: Component {
    /// The closure that takes the time interval since the last update.
    /// 这个闭包接收自上次更新以来的时间间隔作为参数
    let closure: (TimeInterval) -> Void
    // 解释：TimeInterval 是 Double 类型的别名，表示时间间隔（秒）
    // (TimeInterval) -> Void 表示这是一个函数类型，接收时间间隔，不返回任何值

    // Initialize the component by assigning the closure and registering `ClosureSystem`.
    // 初始化组件：分配闭包并注册 ClosureSystem
    init(closure: @escaping (TimeInterval) -> Void) {
        // @escaping 关键字表示这个闭包可能会在函数返回后才被调用
        // 因为动画可能会持续很长时间，所以需要 @escaping
        self.closure = closure
        
        // 注册系统，确保 RealityKit 知道要运行这个更新系统
        ClosureSystem.registerSystem()
    }
}

/// A system that updates the scene over the duration of the app's runtime.
/// 这个系统在应用运行期间持续更新场景
struct ClosureSystem: System {
    /// The query to find entities that contain `ClosureComponent`.
    /// 这个查询用于找到包含 ClosureComponent 的实体
    static let query = EntityQuery(where: .has(ClosureComponent.self))
    // 解释：EntityQuery 是 RealityKit 中用于筛选实体的工具
    // .has(ClosureComponent.self) 表示查找所有拥有 ClosureComponent 的实体

    // 系统初始化器，接收场景参数
    init(scene: RealityKit.Scene) {}
    // 这里是空实现，表示不需要特殊的初始化逻辑

    /// Update entities with `ClosureComponent` at each render frame.
    /// 在每个渲染帧更新拥有 ClosureComponent 的实体
    func update(context: SceneUpdateContext) {
        // SceneUpdateContext 包含了更新所需的上下文信息，比如时间间隔

        // Iterate over all entities in the query.
        // 遍历查询中的所有实体
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            // Self.query 引用上面定义的静态查询
            // .rendering 表示在渲染时更新

            /// The variable to ensure the entity has a `ClosureComponent`.
            /// 确保实体确实有 ClosureComponent 的变量
            guard let comp = entity.components[ClosureComponent.self] else { continue }
            // guard let 是 Swift 的安全检查语法
            // 如果实体没有 ClosureComponent，就跳过这个实体
            // entity.components[ClosureComponent.self] 获取指定类型的组件

            // Execute the closure, and pass the delta time since the last update.
            // 执行闭包，传入自上次更新以来的增量时间
            comp.closure(context.deltaTime)
            // context.deltaTime 是自上一帧以来经过的时间（秒）
            // 调用保存在组件中的闭包函数
        }
    }
}