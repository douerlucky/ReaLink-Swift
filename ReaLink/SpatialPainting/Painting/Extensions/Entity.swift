/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
An extension of the entity class, to include a model component.
*/
// 这是多行注释，说明了这个文件的作用：扩展Entity类以包含模型组件

import RealityKit
// 导入RealityKit框架，这是苹果用于AR/VR开发的框架

/// The extension of the `Entity` class to have a model component variable.
// 这是文档注释，描述了这个扩展的目的

extension Entity {
    // extension关键字用于扩展现有的类，这里扩展了Entity类
    // Entity是RealityKit中的核心类，代表3D场景中的对象
    
    var model: ModelComponent? {
        // 定义一个计算属性叫做model，类型是可选的ModelComponent
        // ModelComponent是用于给Entity添加3D模型的组件
        // 问号(?)表示这个属性可能为nil（没有值）
        
        get { 
            components[ModelComponent.self] 
        }
        // get访问器：当读取model属性时执行
        // components是Entity的组件集合
        // [ModelComponent.self]通过类型来获取对应的组件
        // 相当于：return components[ModelComponent.self]
        
        set { 
            components[ModelComponent.self] = newValue 
        }
        // set访问器：当设置model属性时执行
        // newValue是Swift的隐式参数，代表赋给属性的新值
        // 这行代码将新的ModelComponent设置到Entity的组件集合中
    }
}