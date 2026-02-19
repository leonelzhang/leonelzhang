// LLM data_ctrl模块
// 根据tag信息对data mem进行处理，包括数据的读写操作
module llm_data_ctrl (
    // 时钟和复位
    input logic clk,
    input logic rst_n,
    input logic clk_en, // 时钟门控使能
    
    // 配置接口
    input logic prefetch_en,
    input logic [2:0] prefetch_depth,
    output logic [1:0] split_req_num,
    output logic [2:0] data_ecc_error, // 数据ECC错误标志
    
    // 与PCQ的接口
    input logic [CHI_ADDR_WIDTH-1:0] dc_addr,
    input logic [511:0] dc_data, // 扩展至512位，支持256B请求
    input logic [7:0] dc_size,
    input logic dc_valid,
    input logic [1:0] dc_snp, // SNP请求类型（00: 无 / 01: 读 / 10: 写 / 11: 失效）
    input logic [3:0] dc_type,
    input logic [63:0] dc_pld, // 扩展至64位，支持CHI-H v2.0
    input logic [PRIORITY_WIDTH-1:0] dc_priority,
    output logic dc_ready,
    
    // 与cmd_ctrl的接口
    input logic [TAG_WIDTH-1:0] tag,
    input logic [SET_INDEX_WIDTH-1:0] set_index,
    input logic [OFFSET_WIDTH-1:0] offset,
    input logic [NUM_WAYS-1:0] way_hit,
    input logic [WAY_INDEX_WIDTH-1:0] hit_way,
    input logic cache_hit,
    input logic [WAY_INDEX_WIDTH-1:0] victim_way,
    input logic update_tag,
    input logic [TAG_WIDTH-1:0] new_tag,
    output logic tag_updated,
    
    // 与ecc_ctrl的接口
    input logic [CACHELINE_SIZE*8-1:0] data_corrected,
    input logic [2:0] data_error_status,
    input logic data_error_corrected,
    output logic [CACHELINE_SIZE*8-1:0] data_ecc_in,
    input logic [ECC_BIT_WIDTH*CACHELINE_SIZE/8-1:0] data_ecc_out,
    output logic data_write_en,
    
    // 与prefetch_ctrl的接口
    input logic [CHI_ADDR_WIDTH-1:0] prefetch_addr,
    input logic prefetch_valid,
    input logic [PRIORITY_WIDTH-1:0] prefetch_priority,
    output logic prefetch_ready,
    
    // 与其他模块的接口
    output logic [511:0] cache_data, // 扩展至512位，支持256B响应
    output logic [511:0] snp_data, // 扩展至512位，支持256B响应
    output logic cache_valid,
    output logic snp_valid,
    input logic cache_ready,
    input logic snp_ready
);
    
    // 导入参数
    import llm_params::*;
    
    // Data memory with ECC
    logic [CACHELINE_SIZE*8-1:0] data_mem [NUM_SETS][NUM_WAYS];
    logic [ECC_BIT_WIDTH*CACHELINE_SIZE/8-1:0] data_ecc_mem [NUM_SETS][NUM_WAYS];
    
    // 内部状态
    logic [2:0] state;
    logic [2:0] next_state;
    
    // 数据拆分相关
    logic [1:0] split_count;
    logic [CHI_ADDR_WIDTH-1:0] split_addr [4];
    logic [CHI_DATA_WIDTH-1:0] split_data [4];
    logic [7:0] split_size [4];
    logic [3:0] split_valid;
    
    // 预取相关
    logic [CHI_ADDR_WIDTH-1:0] prefetch_cacheline_addr;
    logic [SET_INDEX_WIDTH-1:0] prefetch_set_index;
    logic [TAG_WIDTH-1:0] prefetch_tag;
    
    // 状态定义
    localparam IDLE = 3'b000;
    localparam PROCESS_CMD = 3'b001;
    localparam SPLIT_REQUEST = 3'b010;
    localparam READ_DATA = 3'b011;
    localparam WRITE_DATA = 3'b100;
    localparam UPDATE_TAG = 3'b101;
    localparam SEND_DATA = 3'b110;
    localparam HANDLE_PREFETCH = 3'b111;
    
    // 计算缓存行地址
    function automatic [CHI_ADDR_WIDTH-1:0] get_cacheline_addr(input logic [CHI_ADDR_WIDTH-1:0] addr);
        return {addr[CHI_ADDR_WIDTH-1:OFFSET_WIDTH], {OFFSET_WIDTH{1'b0}}};
    endfunction
    
    // 计算拆分后的请求数量
    function automatic [1:0] calculate_split_count(input logic [7:0] size);
        if (size <= 64) begin
            return 2'b00; // 1个请求
        end else if (size <= 128) begin
            return 2'b01; // 2个请求
        end else if (size <= 192) begin
            return 2'b10; // 3个请求
        end else begin
            return 2'b11; // 4个请求
        end
    endfunction
    
    // 状态机逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            split_count <= '0;
            split_valid <= '0;
            // 初始化data mem
            for (int i = 0; i < NUM_SETS; i++) begin
                for (int j = 0; j < NUM_WAYS; j++) begin
                    data_mem[i][j] <= '0;
                    data_ecc_mem[i][j] <= '0;
                end
            end
        end else begin
            state <= next_state;
            
            // 数据拆分处理
            if (state == SPLIT_REQUEST) begin
                split_req_num <= calculate_split_count(dc_size);
                split_count <= calculate_split_count(dc_size);
                
                // 生成拆分后的请求
                for (int i = 0; i < 4; i++) begin
                    if (i <= split_count) begin
                        split_addr[i] <= get_cacheline_addr(dc_addr) + (i * CACHELINE_SIZE);
                        split_size[i] <= CACHELINE_SIZE;
                        split_valid[i] <= 1'b1;
                    end else begin
                        split_valid[i] <= 1'b0;
                    end
                end
            end
            
            // 写入数据
            if (state == WRITE_DATA) begin
                if (cache_hit) begin
                    // 缓存命中，写入数据
                    data_mem[set_index][hit_way] <= (ECC_ENABLE && data_error_corrected) ? data_corrected : dc_data;
                    if (ECC_ENABLE) begin
                        data_ecc_mem[set_index][hit_way] <= data_ecc_out;
                    end
                end else begin
                    // 缓存未命中，写入到victim way
                    data_mem[set_index][victim_way] <= (ECC_ENABLE && data_error_corrected) ? data_corrected : dc_data;
                    if (ECC_ENABLE) begin
                        data_ecc_mem[set_index][victim_way] <= data_ecc_out;
                    end
                end
            end
            
            // 处理预取
            if (state == HANDLE_PREFETCH && prefetch_valid) begin
                // 预取数据到victim way
                prefetch_cacheline_addr <= get_cacheline_addr(prefetch_addr);
                prefetch_set_index <= prefetch_cacheline_addr[SET_INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
                prefetch_tag <= prefetch_cacheline_addr[CHI_ADDR_WIDTH-1 : SET_INDEX_WIDTH + OFFSET_WIDTH];
            end
        end
    end
    
    // 下一状态逻辑
    always_comb begin
        next_state = state;
        case (state)
            IDLE:
                if (dc_valid) begin
                    next_state = PROCESS_CMD;
                end else if (prefetch_valid && prefetch_en) begin
                    next_state = HANDLE_PREFETCH;
                end
            
            PROCESS_CMD:
                if (dc_size > CACHELINE_SIZE) begin
                    next_state = SPLIT_REQUEST;
                end else if (dc_type == 4'b0001 || dc_type == 4'b1001) begin // req or rdata
                    next_state = READ_DATA;
                end else if (dc_type == 4'b1000) begin // wdata
                    next_state = WRITE_DATA;
                end else if (update_tag) begin
                    next_state = UPDATE_TAG;
                end else begin
                    next_state = IDLE;
                end
            
            SPLIT_REQUEST:
                next_state = WRITE_DATA;
            
            READ_DATA:
                next_state = SEND_DATA;
            
            WRITE_DATA:
                next_state = SEND_DATA;
            
            UPDATE_TAG:
                next_state = SEND_DATA;
            
            SEND_DATA:
                if (cache_ready && snp_ready) begin
                    next_state = IDLE;
                end
            
            HANDLE_PREFETCH:
                next_state = IDLE;
            
            default:
                next_state = IDLE;
        endcase
    end
    
    // 输出信号逻辑
    always_comb begin
        // 默认值
        dc_ready = 1'b0;
        tag_updated = 1'b0;
        cache_valid = 1'b0;
        snp_valid = 1'b0;
        data_write_en = 1'b0;
        data_ecc_in = '0;
        prefetch_ready = 1'b0;
        split_req_num = 2'b00;
        data_ecc_error = 3'b000;
        
        case (state)
            IDLE:
                if (dc_valid) begin
                    dc_ready = 1'b1;
                end else if (prefetch_valid && prefetch_en) begin
                    prefetch_ready = 1'b1;
                end
            
            PROCESS_CMD:
                dc_ready = 1'b0;
            
            SPLIT_REQUEST:
                split_req_num = calculate_split_count(dc_size);
            
            READ_DATA:
                if (cache_hit) begin
                    // 缓存命中，读取数据
                    if (ECC_ENABLE) begin
                        data_ecc_in = data_mem[set_index][hit_way];
                        data_ecc_error = data_error_status;
                    end
                    cache_data = (ECC_ENABLE && data_error_corrected) ? data_corrected : data_mem[set_index][hit_way];
                    cache_valid = 1'b1;
                end
            
            WRITE_DATA:
                if (cache_hit) begin
                    // 缓存命中，写入数据
                    data_ecc_in = dc_data;
                    data_write_en = 1'b1;
                end else begin
                    // 缓存未命中，写入到victim way
                    data_ecc_in = dc_data;
                    data_write_en = 1'b1;
                end
            
            UPDATE_TAG:
                // 更新tag完成
                tag_updated = 1'b1;
            
            SEND_DATA:
                if (cache_ready) begin
                    cache_valid = 1'b0;
                end
                if (snp_ready) begin
                    snp_valid = 1'b0;
                end
                tag_updated = 1'b0;
            
            HANDLE_PREFETCH:
                prefetch_ready = 1'b1;
            
            default:
                // 默认状态
                dc_ready = 1'b0;
                tag_updated = 1'b0;
                cache_valid = 1'b0;
                snp_valid = 1'b0;
                data_write_en = 1'b0;
            endcase
        end
    end
    
    // SNP数据处理
    always_comb begin
        if (way_hit != '0) begin
            // 找到命中的way，输出snp数据
            for (int i = 0; i < NUM_WAYS; i++) begin
                if (way_hit[i]) begin
                    if (ECC_ENABLE) begin
                        data_ecc_in = data_mem[set_index][i];
                    end
                    snp_data = (ECC_ENABLE && data_error_corrected) ? data_corrected : data_mem[set_index][i];
                    snp_valid = 1'b1;
                    break;
                end
            end
        end else begin
            snp_data = '0;
            snp_valid = 1'b0;
        end
    end
    
endmodule