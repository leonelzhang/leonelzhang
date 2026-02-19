# LLM (Last Level Cache) 设计规格方案

## 1. 设计概述

本设计基于AMBA CHI-H协议实现一个可配置的Last Level Cache (LLM)，支持参数化容量、多路组相联结构、SNP操作和数据拆分功能。

### 1.1 核心特性
- **参数可配置**：容量默认16MB，支持自定义配置
- **缓存结构**：16路组相联，4094组，64B缓存行
- **协议支持**：AMBA CHI-H协议，支持SNP操作
- **数据处理**：支持最大128B访问请求，超过64B自动拆分为多个64B段
- **模块化设计**：采用流水线处理和调度机制，提高性能

## 2. 架构设计

### 2.1 模块分解

| 模块名称 | 功能描述 |
|---------|----------|
| **cmd_ctrl** | 流水处理模块，包含tag mem的管理 |
| **PCQ** | 调度处理模块，管理命令队列 |
| **data_ctrl** | 根据tag信息对data mem进行处理 |
| **chi_slv** | 接收RN接口的AMBA CHI命令请求，进行分类处理 |
| **chi_mst** | 当RN请求miss时，向下游SN发出读请求 |

### 2.2 数据流图

```
+----------------+     +----------------+     +----------------+     +----------------+
|                |     |                |     |                |     |                |
|   chi_slv      | --> |   cmd_ctrl     | --> |     PCQ        | --> |   data_ctrl    |
|                |     |                |     |                |     |                |
+----------------+     +----------------+     +----------------+     +----------------+
          ^                      |                                 |
          |                      v                                 |
          |                +----------------+                       |
          |                |                |                       |
          +----------------+   chi_mst      | <---------------------+
                           |                |
                           +----------------+
```

## 3. 模块详细说明

### 3.1 cmd_ctrl (流水处理模块)

**功能**：
- 处理来自chi_slv的命令
- 管理tag mem，包括tag查找、更新和替换
- 实现流水线处理，提高命令处理效率
- 检测cache hit/miss状态
- 选择victim way进行替换

**关键信号**：
- 输入：命令地址、数据、大小、类型、Pld等
- 输出：tag信息、set索引、偏移量、hit状态、victim way等

### 3.2 PCQ (调度处理模块)

**功能**：
- 管理深度为16的命令队列
- 对命令进行调度，确保合理的执行顺序
- 处理命令优先级和冲突
- 向data_ctrl传递调度后的命令

**关键信号**：
- 输入：来自cmd_ctrl的命令
- 输出：调度后的命令到data_ctrl

### 3.3 data_ctrl (数据处理模块)

**功能**：
- 根据tag信息对data mem进行读写操作
- 处理缓存行的更新和替换
- 与cmd_ctrl交互获取tag相关信息
- 支持缓存行级别的数据操作

**关键信号**：
- 输入：命令信息、tag信息、set索引等
- 输出：缓存数据、SNP数据等

### 3.4 chi_slv (CHI从接口模块)

**功能**：
- 接收RN接口的AMBA CHI命令请求
- 根据req\crsp\srsp\wdata\rdata\snp进行分类处理
- 向上级Cache发送响应
- 处理Pld语段信息

**关键信号**：
- 输入：RN CHI请求信号
- 输出：RN CHI响应信号，处理后的命令到cmd_ctrl

### 3.5 chi_mst (CHI主接口模块)

**功能**：
- 当RN请求miss时，向下游SN发出读请求
- 从下游获取cacheline的数据
- 处理与下游SN的通信
- 管理请求的发送和响应的接收

**关键信号**：
- 输入：来自cmd_ctrl的miss请求
- 输出：SN CHI请求信号，获取的数据到data_ctrl

## 4. 接口定义

### 4.1 顶层接口

| 信号类型 | 信号名称 | 宽度 | 描述 |
|---------|---------|------|------|
| **时钟与复位** | clk | 1 | 系统时钟 |
|  | rst_n | 1 | 异步复位，低电平有效 |
| **RN CHI请求通道** | rn_chi_req_addr | CHI_ADDR_WIDTH | 请求地址 |
|  | rn_chi_req_data | CHI_DATA_WIDTH | 请求数据 |
|  | rn_chi_req_size | 8 | 请求大小 |
|  | rn_chi_req_valid | 1 | 请求有效 |
|  | rn_chi_req_snp | 1 | SNP请求标志 |
|  | rn_chi_req_pld | 32 | 请求Pld信息 |
|  | rn_chi_req_ready | 1 | 请求就绪 |
| **RN CHI响应通道** | rn_chi_resp_data | CHI_DATA_WIDTH | 响应数据 |
|  | rn_chi_resp_valid | 1 | 响应有效 |
|  | rn_chi_resp_error | 1 | 响应错误 |
|  | rn_chi_resp_pld | 32 | 响应Pld信息 |
|  | rn_chi_resp_ready | 1 | 响应就绪 |
| **SN CHI请求通道** | sn_chi_req_addr | CHI_ADDR_WIDTH | 请求地址 |
|  | sn_chi_req_data | CHI_DATA_WIDTH | 请求数据 |
|  | sn_chi_req_size | 8 | 请求大小 |
|  | sn_chi_req_valid | 1 | 请求有效 |
|  | sn_chi_req_snp | 1 | SNP请求标志 |
|  | sn_chi_req_pld | 32 | 请求Pld信息 |
|  | sn_chi_req_ready | 1 | 请求就绪 |
| **SN CHI响应通道** | sn_chi_resp_data | CHI_DATA_WIDTH | 响应数据 |
|  | sn_chi_resp_valid | 1 | 响应有效 |
|  | sn_chi_resp_error | 1 | 响应错误 |
|  | sn_chi_resp_pld | 32 | 响应Pld信息 |
|  | sn_chi_resp_ready | 1 | 响应就绪 |

### 4.2 模块间接口

#### 4.2.1 chi_slv → cmd_ctrl
| 信号名称 | 宽度 | 描述 |
|---------|------|------|
| cmd_addr | CHI_ADDR_WIDTH | 命令地址 |
| cmd_data | CHI_DATA_WIDTH | 命令数据 |
| cmd_size | 8 | 命令大小 |
| cmd_valid | 1 | 命令有效 |
| cmd_snp | 1 | SNP命令标志 |
| cmd_type | 4 | 命令类型 |
| cmd_pld | 32 | 命令Pld信息 |
| cmd_ready | 1 | 命令就绪 |

#### 4.2.2 cmd_ctrl → PCQ
| 信号名称 | 宽度 | 描述 |
|---------|------|------|
| pcq_addr | CHI_ADDR_WIDTH | PCQ地址 |
| pcq_data | CHI_DATA_WIDTH | PCQ数据 |
| pcq_size | 8 | PCQ大小 |
| pcq_valid | 1 | PCQ有效 |
| pcq_snp | 1 | PCQ SNP标志 |
| pcq_type | 4 | PCQ类型 |
| pcq_pld | 32 | PCQ Pld信息 |
| pcq_ready | 1 | PCQ就绪 |

#### 4.2.3 PCQ → data_ctrl
| 信号名称 | 宽度 | 描述 |
|---------|------|------|
| dc_addr | CHI_ADDR_WIDTH | 数据控制地址 |
| dc_data | CHI_DATA_WIDTH | 数据控制数据 |
| dc_size | 8 | 数据控制大小 |
| dc_valid | 1 | 数据控制有效 |
| dc_snp | 1 | 数据控制SNP标志 |
| dc_type | 4 | 数据控制类型 |
| dc_pld | 32 | 数据控制Pld信息 |
| dc_ready | 1 | 数据控制就绪 |

#### 4.2.4 cmd_ctrl → data_ctrl
| 信号名称 | 宽度 | 描述 |
|---------|------|------|
| tag | TAG_WIDTH | 标签信息 |
| set_index | SET_INDEX_WIDTH | 组索引 |
| offset | OFFSET_WIDTH | 偏移量 |
| way_hit | NUM_WAYS | 路命中标志 |
| hit_way | WAY_INDEX_WIDTH | 命中路索引 |
| cache_hit | 1 | 缓存命中标志 |
| victim_way | WAY_INDEX_WIDTH | 替换路索引 |
| update_tag | 1 | 更新标签标志 |
| new_tag | TAG_WIDTH | 新标签信息 |
| tag_updated | 1 | 标签已更新标志 |

#### 4.2.5 cmd_ctrl → chi_mst
| 信号名称 | 宽度 | 描述 |
|---------|------|------|
| mst_addr | CHI_ADDR_WIDTH | 主接口地址 |
| mst_size | 8 | 主接口大小 |
| mst_valid | 1 | 主接口有效 |
| mst_snp | 1 | 主接口SNP标志 |
| mst_ready | 1 | 主接口就绪 |

## 5. 功能特性

### 5.1 缓存操作
- **读操作**：支持单缓存行和跨缓存行读取
- **写操作**：支持单缓存行和跨缓存行写入
- **替换策略**：实现伪LRU或随机替换算法
- **SNP操作**：支持对上级缓存的snoop操作

### 5.2 数据处理
- **数据拆分**：自动将超过64B的请求拆分为多个64B段
- **最大访问**：支持最大128B访问请求
- **Pld处理**：支持AMBA CHI-H协议的Pld语段处理

### 5.3 错误处理
- **响应错误**：当操作失败时返回错误响应
- **超时处理**：处理请求超时情况
- **协议错误**：检测和处理协议错误

## 6. 性能参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 时钟频率 | 1GHz (典型) | 可根据工艺调整 |
| 延迟 | 3-5 时钟周期 | 缓存命中情况下的访问延迟 |
| 带宽 | 64GB/s | 1GHz时钟下的理论带宽 |
| 最大命令队列深度 | 16 | PCQ模块的队列深度 |
| 最大并发请求数 | 16 | 支持的最大并发请求数 |

## 7. 测试方案

### 7.1 功能测试
- **基本读写测试**：验证单缓存行读写操作
- **缓存命中测试**：验证缓存命中情况下的正确处理
- **缓存未命中测试**：验证缓存未命中时的miss处理和下游请求
- **SNP操作测试**：验证SNP操作的正确性
- **数据拆分测试**：验证超过64B请求的拆分处理

### 7.2 性能测试
- **带宽测试**：测量不同访问模式下的带宽
- **延迟测试**：测量不同操作的延迟
- **并发测试**：测试最大并发请求处理能力

### 7.3 边界测试
- **地址边界测试**：测试地址边界情况
- **大小边界测试**：测试最小和最大访问大小
- **极限并发测试**：测试最大并发请求数

## 8. 实现细节

### 8.1 代码结构

```
LLM/
├── llm_params.sv         # 参数配置文件
├── llm_top.sv            # 顶层模块
├── llm_chi_slv.sv        # CHI从接口模块
├── llm_cmd_ctrl.sv       # 命令控制模块
├── llm_pcq.sv            # 命令队列模块
├── llm_data_ctrl.sv      # 数据控制模块
├── llm_chi_mst.sv        # CHI主接口模块
├── llm_data_split.sv     # 数据拆分模块
├── llm_chi_pld.sv        # CHI Pld处理模块
├── llm_test.sv           # 测试文件
└── LLM_Design_Specification.md # 设计规格文档
```

### 8.2 关键参数

| 参数 | 默认值 | 说明 |
|------|-------|------|
| CACHE_CAPACITY | 16MB | 缓存容量 |
| NUM_WAYS | 16 | 路数 |
| NUM_SETS | 4094 | 组数 |
| CACHELINE_SIZE | 64B | 缓存行大小 |
| MAX_ACCESS_SIZE | 128B | 最大访问大小 |

## 9. 结论

本设计实现了一个功能完整、性能优良的Last Level Cache，基于AMBA CHI-H协议，支持参数化配置、多路组相联结构、SNP操作和数据拆分功能。通过模块化设计和流水线处理，提高了缓存的性能和可靠性，满足了现代系统对高速缓存的需求。

### 9.1 优势
- 模块化设计，易于维护和扩展
- 参数可配置，适应不同应用场景
- 支持完整的AMBA CHI-H协议特性
- 高效的数据处理和调度机制
- 全面的测试覆盖

### 9.2 应用场景
- 高性能计算系统
- 服务器处理器
- 嵌入式系统
- 任何需要高速缓存的计算环境

---

**版本**：1.0
**日期**：2026-02-19
**作者**：LLM设计团队