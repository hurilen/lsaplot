# lsaplot：规范事件研究法绘图命令使用指南

**Li San'an Event Study Plot (v1.1.0)**

---

## 1. 命令简介

**`lsaplot`** 是一个专为实证研究设计的 Stata 命令，旨在以最简便的代码，一键完成**事件研究法 (Event Study)** 的模型估计与可视化绘图。

### 核心亮点

1. **顶刊审美**：默认输出对标 *American Economic Review (AER)* 风格的图像（深蓝实心点、工字型置信区间、紧凑边框、Times New Roman字体）。
2. **智能引擎**：内置"智能切换"逻辑。常规情况使用轻量级的 `xtreg`；当涉及多维固定效应或非嵌套聚类时，自动切换至 `reghdfe`，避免报错。
3. **精确归并**：支持 **Binning (缩尾归并)** 和 **Trimming (截断)** 两种处理窗口外样本的模式，符合最新计量经济学文献规范。
4. **稳健防崩**：采用"变量前置"与"无引号参数"架构，彻底解决了中文字符和特殊符号可能导致的 `matching brace not found` 等红字报错。

---

## 2. 安装与环境

### 2.1 安装方法

将生成的 `lsaplot.ado` 文件保存至以下任意路径：

* **推荐**：Stata 个人 ADO 目录（如 `C:\ado\plus\l\` 或用户文件夹下）。
* **临时**：当前项目的工作路径（Working Directory）。

### 2.2 必要依赖

由于具备智能引擎切换功能，**强烈建议**预先安装 `reghdfe` 套件：

```stata
ssc install reghdfe, replace
ssc install ftools, replace
```

---

## 3. 计量原理 (Methodology)

`lsaplot` 估计的是如下标准的事件研究方程：

$$
Y_{it} = \mu_i + \lambda_t + \sum_{k=underline{k}}^{\bar{k}} \beta_k \cdot D_{it}^k + \delta X_{it} + \epsilon_{it}
$$

其中：

* $D_{it}^k$ 是相对时间虚拟变量（Dummy Variable），当 $t - T_{treat} = k$ 时为 1。
* 命令自动处理基准期（Base Period），默认将 $k=-1$ 的系数标准化为 0。

### 关于窗口外样本的处理（特色功能）

当样本的相对时间超出设定的 `[start, end]` 区间时，`lsaplot` 提供两种处理方式：

1. **Binning (归并/缩尾) `bin`** [推荐]:
   * 将所有早于 `start` 的时期归集到 `start` 上；将所有晚于 `end` 的时期归集到 `end` 上。
   * 这有助于捕捉长期趋势的累积效应（类似 Sun & Abraham, 2021 的建议）。
2. **Trimming (截断) `trim`**:
   * 直接删除窗口区间之外的处理组样本。
   * 这是一种更纯粹的局部窗口估计。
3. **默认 (Default)**:
   * 既不删除也不归并。窗口外的 dummy 此时未生成，这部分样本的变异会进入基准组（Base）。

---

## 4. 语法格式

```stata
lsaplot depvar [indepvars] [if] [in], ///
        Treat(varname) ID(varname) Time(varname) ///
        [Options]
```

* **`depvar`**: 被解释变量。
* **`[indepvars]`**: （可选）控制变量列表。

### 必填核心选项

| 选项               | 描述         | 注意事项                                                            |
|:---------------- |:---------- |:--------------------------------------------------------------- |
| **`Treat(var)`** | **政策时间变量** | 必须填入受处理的具体**年份/时间数值**（如2012）。<br>控制组该变量需为 `0` 或 `.`。不要填0/1虚拟变量。 |
| **`ID(var)`**    | **个体ID**   | 面板个体的唯一标识（如股票代码、城市代码）。                                          |
| **`Time(var)`**  | **时间变量**   | 面板的时间标识（如年份）。                                                   |

### 选填参数

| 选项             | 缩写   | 默认值      | 描述                                          |
|:-------------- |:---- |:-------- |:------------------------------------------- |
| `start(#)`     | -    | 自动       | 绘图窗口起始期（如 -5）。不填则取最小值。                      |
| `end(#)`       | -    | 自动       | 绘图窗口结束期（如 5）。不填则取最大值。                       |
| `base(#)`      | -    | `-1`     | 基准期，该期系数会被 omission 并不在图上显示。                |
| `level(#)`     | `le` | `95`     | 置信水平（90, 95, 99）。                           |
| `cluster(var)` | `cl` | `robust` | 标准误聚类层级。支持任意层级聚类。                           |
| `absorb(str)`  | `a`  | 自动       | 自定义高维固定效应。**一旦指定，将强制使用 reghdfe 并不再默认控制年份。** |
| `bin`          | -    | 否        | **归并模式**：累积窗口外的样本效应。                        |
| `trim`         | -    | 否        | **截断模式**：删除窗口外的处理组样本。                       |
| `title(str)`   | -    | -        | 图片标题。支持中文。                                  |                  |
| `keepdata`     | -    | -        | 保留绘图用的数据（会替换当前内存数据）。                        |
| `nograph`      | -    | -        | 仅跑回归，不画图。                                   |

---

## 5. 操作实战案例 (Cookbook)

### 场景一：快速预览（Default Mode）

只想看一眼 Y 和政策的基本动态关系，不需要控制变量。

```stata
lsaplot lnemp, treat(policy_year) id(stkcd) time(year)
```

> **结果**：自动识别全样本区间，使用稳健标准误，个体+年份双固定效应。

### 场景二：标准 DID 论文图（AER Standard）

加入控制变量，按行业聚类标准误，设定 [-5, 5] 窗口，并采用 **Binning (归并)** 模式防止偏差。

```stata
lsaplot lnemp Size Lev ROA, ///    (因变量 + 控制变量)
    treat(policy_year) id(stkcd) time(year) ///
    start(-5) end(5) base(-1) ///  (设定窗口和基准)
    cl(industry) bin ///           (行业聚类 + 归并模式)
    title("The Dynamic Effect on Employment")
```

> **智能切换**：程序会自动检测到 `industry != stkcd`，后台静默切换至 `reghdfe` 引擎以正确处理非嵌套聚类。

### 场景三：高维固定效应（Power Mode）

需要控制 **"行业-年份"** 和 **"省份-年份"** 联合固定效应。

```stata
lsaplot lnemp Controls, ///
    treat(policy_year) id(stkcd) time(year) ///
    a(stkcd industry#year province#year) ///  (完全自定义吸收项)
    cl(stkcd) trim                           // (使用截断模式)
```

> **逻辑**：使用了 `a()` 选项，命令进入 Power Mode，完全遵从你的吸收设定，不再自动加 `i.year`。

---

## 6. 图表审美特征

`lsaplot` 生成的图表无需后期编辑，直接符合 Top 期刊要求：

1. **颜色 (Colors)**：
   * **标记点**：**深海军蓝 (Dark Navy)**，稳重且具有学术感，区别于默认的纯黑或刺眼的蓝色。
   * **连接线**：纯黑实线。
2. **置信区间 (Confidence Intervals)**：
   * 采用 **"工"字型 (I-Bar)** 设计。
   * **实线**的中灰色 (`gs7`) 细棒，避免虚线带来的视觉杂乱感，更加精致。
3. **布局 (Layout)**：
   * **紧凑**：相对时间的间距被压缩，点与图表边缘只有 0.2 单位的距离，最大化数据展示区域。
   * **外框**：带有极细的黑色外框 (`plotregion box`)。
   * **留白**：图表外部保留适度的白色边缘，防止文字溢出。
4. **字体**：自动尝试调用系统 **Times New Roman**。对于中文标题，Windows 系统会自动回退到**宋体**，完美实现"中西合璧"。

---

## 7. 常见问题 (FAQ)

**Q1: 为什么提示 "matching close brace not found"?**

* **答**：在旧版本中可能因为颜色代码或中文字符的引号嵌套导致。**V1.1.0** 已通过移除引号和重构代码彻底修复此问题，请确保使用的是最新版。

**Q2: 为什么回归结果和 `xtreg` 手跑的不一样？**

* **答**：请检查窗口外的样本处理。手动 `xtreg` 通常将窗口外的 dummy 归入基准组。如果你在 `lsaplot` 中用了 `trim`，样本量变少了，系数自然不同；如果你用了 `bin`，系数组合方式也不同。这是方法论选择的问题。

**Q3: 如何导出图片？**

* **答**：命令运行完后图片会显示在窗口中。直接使用 Stata 标准命令：
  
  ```stata
  graph export "MyFigure.png", width(2000) replace
  graph export "MyFigure.pdf", replace
  ```

**Q4: 可以跑倍分法 (Difference-in-Differences) 吗？**

* **答**：可以。事件研究法本质上就是动态的 DID。只要你有 Treated (id), Post (time) 信息构成的 `Treat` 变量，这个命令通吃。

---

**Happy Researching, Li San'an.**
