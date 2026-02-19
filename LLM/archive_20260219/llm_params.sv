// LLM参数配置包
package llm_params;
    // 可配置参数：支持4MB~64MB容量，8/16/32路，64B/128B cacheline
    parameter int CACHE_CAPACITY = 16 * 1024 * 1024; // 默认16MB，可选4MB/8MB/16MB/32MB/64MB
    parameter int NUM_WAYS = 16; // 默认16路，可选8/16/32路
    parameter int NUM_SETS = 4096; // 4096个set（2的幂次，简化地址映射）
    parameter int CACHELINE_SIZE = 64; // 默认64B cacheline，可选64B/128B
    parameter int MAX_ACCESS_SIZE = 256; // 最大256B访问请求

    // PCQ相关参数
    parameter int PCQ_DEPTH = 32; // PCQ队列深度

    // ECC相关参数
    parameter bit ECC_ENABLE = 1; // ECC使能标志
    parameter int ECC_BIT_WIDTH = 8; // ECC校验位宽度

    // 预取相关参数
    parameter bit PREFETCH_ENABLE = 1; // 预取使能标志
    parameter int PREFETCH_DEPTH = 4; // 预取深度

    // 优先级相关参数
    parameter int PRIORITY_WIDTH = 3; // 优先级宽度（0-7级）

    // 计算衍生参数
    parameter int SET_INDEX_WIDTH = $clog2(NUM_SETS);
    parameter int WAY_INDEX_WIDTH = $clog2(NUM_WAYS);
    parameter int OFFSET_WIDTH = $clog2(CACHELINE_SIZE);
    parameter int TAG_WIDTH = 64 - SET_INDEX_WIDTH - OFFSET_WIDTH;

    // CHI-H协议相关参数
    parameter int CHI_DATA_WIDTH = 64; // 64位数据总线
    parameter int CHI_ADDR_WIDTH = 64; // 64位地址总线
    parameter int CHI_TXN_ID_WIDTH = 16; // 16位事务ID
    parameter int CHI_VERSION = 2; // CHI-H v2.0协议

    // 状态定义
    enum logic [2:0] {
        INVALID = 3'b000,
        VALID   = 3'b001,
        SHARED  = 3'b010,
        MODIFIED = 3'b011
    } cache_state_e;

    // 替换策略定义
    enum logic [1:0] {
        REPLACE_LRU = 2'b00,
        REPLACE_PLRU = 2'b01,
        REPLACE_RANDOM = 2'b10
    } replace_policy_e;

    // 流水线阶段定义
    enum logic [2:0] {
        PIPE_FETCH = 3'b000,
        PIPE_ADDR_DECODE = 3'b001,
        PIPE_TAG_LOOKUP = 3'b010,
        PIPE_HIT_CHECK = 3'b011,
        PIPE_REPLACE_DECISION = 3'b100
    } pipeline_stage_e;
endpackage