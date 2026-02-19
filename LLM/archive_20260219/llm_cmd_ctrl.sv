// LLM命令控制模块
// 包含5级流水线处理和tag mem管理
module llm_cmd_ctrl (
    // 时钟和复位
    input logic clk,
    input logic rst_n,
    
    // 配置接口
    input logic [1:0] replace_policy, // 替换策略：00:LRU, 01:PLRU, 10:随机
    input logic ecc_en, // ECC使能标志
    
    // 与chi_slv的接口
    input logic [CHI_ADDR_WIDTH-1:0] cmd_addr,
    input logic [CHI_DATA_WIDTH-1:0] cmd_data,
    input logic [7:0] cmd_size,
    input logic cmd_valid,
    input logic cmd_snp,
    input logic [3:0] cmd_type,
    input logic [31:0] cmd_pld,
    input logic [PRIORITY_WIDTH-1:0] cmd_priority,
    output logic cmd_ready,
    
    // 与PCQ的接口
    output logic [CHI_ADDR_WIDTH-1:0] pcq_addr,
    output logic [CHI_DATA_WIDTH-1:0] pcq_data,
    output logic [7:0] pcq_size,
    output logic pcq_valid,
    output logic pcq_snp,
    output logic [3:0] pcq_type,
    output logic [31:0] pcq_pld,
    output logic [PRIORITY_WIDTH-1:0] pcq_priority,
    input logic pcq_ready,
    
    // 与data_ctrl的接口
    output logic [TAG_WIDTH-1:0] tag,
    output logic [SET_INDEX_WIDTH-1:0] set_index,
    output logic [OFFSET_WIDTH-1:0] offset,
    output logic [NUM_WAYS-1:0] way_hit,
    output logic [WAY_INDEX_WIDTH-1:0] hit_way,
    output logic cache_hit,
    output logic [WAY_INDEX_WIDTH-1:0] victim_way,
    output logic update_tag,
    output logic [TAG_WIDTH-1:0] new_tag,
    input logic tag_updated,
    
    // 与chi_mst的接口
    output logic [CHI_ADDR_WIDTH-1:0] mst_addr,
    output logic [7:0] mst_size,
    output logic mst_valid,
    output logic mst_snp,
    output logic [PRIORITY_WIDTH-1:0] mst_priority,
    input logic mst_ready,
    
    // 与chi_slv的响应接口
    output logic [CHI_DATA_WIDTH-1:0] rsp_data,
    output logic rsp_valid,
    output logic rsp_error,
    output logic [31:0] rsp_pld,
    input logic rsp_ready,
    
    // 与ecc_ctrl的接口
    output logic [TAG_WIDTH-1:0] tag_ecc_in,
    input logic [ECC_BIT_WIDTH-1:0] tag_ecc_out,
    input logic [2:0] tag_error_status,
    input logic tag_error_corrected,
    input logic [TAG_WIDTH-1:0] tag_corrected,
    
    // 与prefetch_ctrl的接口
    output logic [CHI_ADDR_WIDTH-1:0] access_addr,
    output logic access_valid,
    output logic access_is_write,
    
    // 状态输出
    output logic [2:0] pipeline_stage,
    output logic [2:0] tag_ecc_error
);
    
    // 导入参数
    import llm_params::*;
    
    // 内部信号
    // 5级流水线寄存器
    typedef struct {
        logic [CHI_ADDR_WIDTH-1:0] addr;
        logic [CHI_DATA_WIDTH-1:0] data;
        logic [7:0] size;
        logic snp;
        logic [3:0] type;
        logic [31:0] pld;
        logic [PRIORITY_WIDTH-1:0] priority;
        logic valid;
        logic is_write;
    } pipe_stage_t;
    
    pipe_stage_t pipe [5]; // 5级流水线：取指→地址解析→tag查找→命中判断→替换决策
    
    // Tag memory with ECC
    logic [TAG_WIDTH-1:0] tag_mem [NUM_SETS][NUM_WAYS];
    logic [ECC_BIT_WIDTH-1:0] tag_ecc_mem [NUM_SETS][NUM_WAYS];
    logic [NUM_WAYS-1:0] valid_mem [NUM_SETS];
    
    // 替换策略相关
    logic [NUM_WAYS-1:0] lru_cnt [NUM_SETS]; // LRU计数器
    logic [NUM_WAYS-1:0] plru_state [NUM_SETS]; // PLRU状态
    logic [WAY_INDEX_WIDTH-1:0] rand_cnt; // 随机计数器
    
    // 状态机
    logic [2:0] state;
    logic [2:0] next_state;
    
    // 状态定义
    localparam IDLE = 3'b000;
    localparam FETCH = 3'b001;
    localparam DECODE = 3'b010;
    localparam TAG_LOOKUP = 3'b011;
    localparam HIT_CHECK = 3'b100;
    localparam REPLACE_DECISION = 3'b101;
    localparam PCQ_DISPATCH = 3'b110;
    localparam MEM_ACCESS = 3'b111;
    
    // 地址分解
    assign tag = pipe[1].addr[CHI_ADDR_WIDTH-1 : SET_INDEX_WIDTH + OFFSET_WIDTH];
    assign set_index = pipe[1].addr[SET_INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
    assign offset = pipe[1].addr[OFFSET_WIDTH-1 : 0];
    
    // 与prefetch_ctrl的接口
    assign access_addr = pipe[0].addr;
    assign access_valid = pipe[0].valid;
    assign access_is_write = pipe[0].is_write;
    
    // 与ecc_ctrl的接口
    assign tag_ecc_in = tag;
    assign tag_ecc_error = tag_error_status;
    
    // 流水线阶段
    assign pipeline_stage = state[2:0];
    
    // 计算way_hit和cache_hit
    always_comb begin
        way_hit = '0;
        for (int i = 0; i < NUM_WAYS; i++) begin
            if (valid_mem[set_index][i] && (tag_mem[set_index][i] == tag)) begin
                way_hit[i] = 1'b1;
            end
        end
        cache_hit = |way_hit;
    end
    
    // 计算hit_way
    always_comb begin
        hit_way = '0;
        for (int i = 0; i < NUM_WAYS; i++) begin
            if (way_hit[i]) begin
                hit_way = i;
                break;
            end
        end
    end
    
    // 计算victim_way (可配置替换策略)
    always_comb begin
        case (replace_policy)
            2'b00: begin // LRU
                // 选择LRU计数器最大的way
                victim_way = 0;
                for (int i = 1; i < NUM_WAYS; i++) begin
                    if (lru_cnt[set_index][i] > lru_cnt[set_index][victim_way]) begin
                        victim_way = i;
                    end
                end
            end
            2'b01: begin // PLRU
                // 简化的PLRU实现
                victim_way = 0;
                for (int i = 0; i < NUM_WAYS; i++) begin
                    if (!plru_state[set_index][i]) begin
                        victim_way = i;
                        break;
                    end
                end
            end
            2'b10: begin // 随机
                victim_way = rand_cnt;
            end
            default: begin // 默认LRU
                victim_way = 0;
                for (int i = 1; i < NUM_WAYS; i++) begin
                    if (lru_cnt[set_index][i] > lru_cnt[set_index][victim_way]) begin
                        victim_way = i;
                    end
                end
            end
        endcase
    end
    
    // 随机数生成
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rand_cnt <= '0;
        end else begin
            rand_cnt <= rand_cnt + 1;
        end
    end
    
    // 状态机逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            // 初始化流水线
            for (int i = 0; i < 5; i++) begin
                pipe[i].valid <= 1'b0;
            end
            // 初始化tag mem
            for (int i = 0; i < NUM_SETS; i++) begin
                valid_mem[i] <= '0;
                lru_cnt[i] <= '0;
                plru_state[i] <= '0;
                for (int j = 0; j < NUM_WAYS; j++) begin
                    tag_mem[i][j] <= '0;
                    tag_ecc_mem[i][j] <= '0;
                end
            end
        end else begin
            state <= next_state;
            
            // 流水线推进
            case (state)
                IDLE:
                    if (cmd_valid) begin
                        // 取指阶段
                        pipe[0].addr <= cmd_addr;
                        pipe[0].data <= cmd_data;
                        pipe[0].size <= cmd_size;
                        pipe[0].snp <= cmd_snp;
                        pipe[0].type <= cmd_type;
                        pipe[0].pld <= cmd_pld;
                        pipe[0].priority <= cmd_priority;
                        pipe[0].valid <= 1'b1;
                        pipe[0].is_write <= (cmd_type == 4'b0010); // 假设0010是写命令
                    end
                
                FETCH:
                    // 地址解析阶段
                    pipe[1] <= pipe[0];
                    pipe[0].valid <= 1'b0;
                
                DECODE:
                    // tag查找阶段
                    pipe[2] <= pipe[1];
                    pipe[1].valid <= 1'b0;
                
                TAG_LOOKUP:
                    // 命中判断阶段
                    pipe[3] <= pipe[2];
                    pipe[2].valid <= 1'b0;
                
                HIT_CHECK:
                    // 替换决策阶段
                    pipe[4] <= pipe[3];
                    pipe[3].valid <= 1'b0;
                
                REPLACE_DECISION:
                    pipe[4].valid <= 1'b0;
            endcase
            
            // 更新替换策略状态
            if (cache_hit && pipe[3].valid) begin
                case (replace_policy)
                    2'b00: begin // LRU
                        // 更新LRU计数器
                        lru_cnt[set_index][hit_way] <= 0;
                        for (int i = 0; i < NUM_WAYS; i++) begin
                            if (i != hit_way && valid_mem[set_index][i]) begin
                                lru_cnt[set_index][i] <= lru_cnt[set_index][i] + 1;
                            end
                        end
                    end
                    2'b01: begin // PLRU
                        // 更新PLRU状态
                        plru_state[set_index][hit_way] <= 1'b1;
                        for (int i = 0; i < NUM_WAYS; i++) begin
                            if (i != hit_way) begin
                                plru_state[set_index][i] <= 1'b0;
                            end
                        end
                    end
                endcase
            end
            
            // 更新tag mem
            if (update_tag && tag_updated) begin
                tag_mem[set_index][victim_way] <= new_tag;
                if (ECC_ENABLE) begin
                    tag_ecc_mem[set_index][victim_way] <= tag_ecc_out;
                end
                valid_mem[set_index][victim_way] <= 1'b1;
                
                // 更新替换策略状态
                case (replace_policy)
                    2'b00: begin // LRU
                        lru_cnt[set_index][victim_way] <= 0;
                        for (int i = 0; i < NUM_WAYS; i++) begin
                            if (i != victim_way && valid_mem[set_index][i]) begin
                                lru_cnt[set_index][i] <= lru_cnt[set_index][i] + 1;
                            end
                        end
                    end
                    2'b01: begin // PLRU
                        plru_state[set_index][victim_way] <= 1'b1;
                        for (int i = 0; i < NUM_WAYS; i++) begin
                            if (i != victim_way) begin
                                plru_state[set_index][i] <= 1'b0;
                            end
                        end
                    end
                endcase
            end
        end
    end
    
    // 下一状态逻辑
    always_comb begin
        next_state = state;
        case (state)
            IDLE:
                if (cmd_valid) begin
                    next_state = FETCH;
                end
            
            FETCH:
                next_state = DECODE;
            
            DECODE:
                next_state = TAG_LOOKUP;
            
            TAG_LOOKUP:
                next_state = HIT_CHECK;
            
            HIT_CHECK:
                if (cache_hit) begin
                    next_state = REPLACE_DECISION;
                end else begin
                    next_state = MEM_ACCESS;
                end
            
            REPLACE_DECISION:
                next_state = PCQ_DISPATCH;
            
            PCQ_DISPATCH:
                if (pcq_ready) begin
                    next_state = IDLE;
                end
            
            MEM_ACCESS:
                if (mst_ready) begin
                    next_state = REPLACE_DECISION;
                end
            
            default:
                next_state = IDLE;
        endcase
    end
    
    // 输出信号逻辑
    always_comb begin
        // 默认值
        cmd_ready = 1'b0;
        pcq_valid = 1'b0;
        mst_valid = 1'b0;
        rsp_valid = 1'b0;
        update_tag = 1'b0;
        new_tag = '0;
        
        case (state)
            IDLE:
                if (cmd_valid) begin
                    cmd_ready = 1'b1;
                end
            
            HIT_CHECK:
                if (cache_hit) begin
                    // 缓存命中，准备发送到PCQ
                    pcq_addr = pipe[3].addr;
                    pcq_data = pipe[3].data;
                    pcq_size = pipe[3].size;
                    pcq_snp = pipe[3].snp;
                    pcq_type = pipe[3].type;
                    pcq_pld = pipe[3].pld;
                    pcq_priority = pipe[3].priority;
                    pcq_valid = 1'b1;
                end else begin
                    // 缓存未命中，发送到chi_mst
                    mst_addr = pipe[3].addr;
                    mst_size = pipe[3].size;
                    mst_snp = pipe[3].snp;
                    mst_priority = pipe[3].priority;
                    mst_valid = 1'b1;
                    // 准备更新tag
                    update_tag = 1'b1;
                    new_tag = tag;
                end
            
            PCQ_DISPATCH:
                if (pcq_ready) begin
                    // 准备响应
                    rsp_data = pipe[4].data;
                    rsp_valid = 1'b1;
                    rsp_error = 1'b0;
                    rsp_pld = pipe[4].pld;
                end
            
            MEM_ACCESS:
                if (mst_ready) begin
                    // 发送到PCQ
                    pcq_addr = pipe[3].addr;
                    pcq_data = pipe[3].data;
                    pcq_size = pipe[3].size;
                    pcq_snp = pipe[3].snp;
                    pcq_type = pipe[3].type;
                    pcq_pld = pipe[3].pld;
                    pcq_priority = pipe[3].priority;
                    pcq_valid = 1'b1;
                end
        endcase
    end
    
    // ECC处理
    always_comb begin
        if (ECC_ENABLE) begin
            tag_ecc_in = tag;
        end else begin
            tag_ecc_in = '0;
        end
    end
    
endmodule