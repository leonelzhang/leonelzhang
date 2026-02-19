// LLM缓存核心模块
// 实现tag比较、数据访问和snp操作
module llm_core (
    // 时钟和复位
    input logic clk,
    input logic rst_n,
    
    // 输入信号
    input logic [TAG_WIDTH-1:0] tag,
    input logic [SET_INDEX_WIDTH-1:0] set_index,
    input logic [OFFSET_WIDTH-1:0] offset,
    input logic [CHI_DATA_WIDTH-1:0] req_data,
    input logic [7:0] req_size,
    input logic req_valid,
    input logic req_snp,
    output logic req_ready,
    
    // 输出信号
    output logic [NUM_WAYS-1:0] way_hit,
    output logic [WAY_INDEX_WIDTH-1:0] hit_way,
    output logic cache_hit,
    output logic [CACHELINE_SIZE-1:0] cache_data,
    output logic [CACHELINE_SIZE-1:0] snp_data,
    output logic snp_valid
);
    
    // 导入参数
    import llm_params::*;
    
    // 缓存数组
    logic [TAG_WIDTH-1:0] tag_array [NUM_SETS][NUM_WAYS];
    logic [CACHELINE_SIZE-1:0] data_array [NUM_SETS][NUM_WAYS];
    cache_state_e state_array [NUM_SETS][NUM_WAYS];
    logic [WAY_INDEX_WIDTH-1:0] lru_array [NUM_SETS];
    
    // 内部信号
    logic [NUM_WAYS-1:0] way_valid;
    logic [NUM_WAYS-1:0] tag_match;
    logic [WAY_INDEX_WIDTH-1:0] victim_way;
    
    // 计算way_valid和tag_match
    always_comb begin
        for (int i = 0; i < NUM_WAYS; i++) begin
            way_valid[i] = (state_array[set_index][i] != INVALID);
            tag_match[i] = (tag_array[set_index][i] == tag) && way_valid[i];
        end
        way_hit = tag_match;
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
    
    // 计算victim_way（LRU策略）
    always_comb begin
        victim_way = lru_array[set_index];
    end
    
    // 缓存访问逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位所有缓存状态
            for (int i = 0; i < NUM_SETS; i++) begin
                for (int j = 0; j < NUM_WAYS; j++) begin
                    state_array[i][j] <= INVALID;
                    tag_array[i][j] <= '0;
                    data_array[i][j] <= '0;
                end
                lru_array[i] <= '0;
            end
            req_ready <= 1'b1;
            snp_valid <= 1'b0;
        end else begin
            // 默认值
            req_ready <= 1'b1;
            snp_valid <= 1'b0;
            
            if (req_valid && req_ready) begin
                if (req_snp) begin
                    // SNP操作：返回请求的数据
                    for (int i = 0; i < NUM_WAYS; i++) begin
                        if (tag_match[i]) begin
                            snp_data <= data_array[set_index][i];
                            snp_valid <= 1'b1;
                            // 更新状态为SHARED
                            state_array[set_index][i] <= SHARED;
                            break;
                        end
                    end
                end else begin
                    // 普通访问操作
                    if (cache_hit) begin
                        // Cache hit: 读取或写入数据
                        if (req_size > 0) begin
                            // 写入操作
                            data_array[set_index][hit_way] <= req_data;
                            state_array[set_index][hit_way] <= MODIFIED;
                        end else begin
                            // 读取操作
                            cache_data <= data_array[set_index][hit_way];
                        end
                        // 更新LRU
                        lru_array[set_index] <= hit_way;
                    end else begin
                        // Cache miss: 替换策略
                        data_array[set_index][victim_way] <= req_data;
                        tag_array[set_index][victim_way] <= tag;
                        state_array[set_index][victim_way] <= MODIFIED;
                        // 更新LRU
                        lru_array[set_index] <= victim_way;
                    end
                end
            end
        end
    end
    
endmodule