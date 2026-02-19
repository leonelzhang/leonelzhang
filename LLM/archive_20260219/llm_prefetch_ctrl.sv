// LLM 预取控制模块
// 支持基于地址局部性的硬件预取，可配置预取深度和策略
module llm_prefetch_ctrl (
    // 时钟和复位
    input logic clk,
    input logic rst_n,
    
    // 配置接口
    input logic prefetch_en, // 预取使能
    input logic [2:0] prefetch_depth, // 预取深度（1-8行）
    input logic [1:0] prefetch_policy, // 预取策略：00: 顺序预取, 01:  stride预取, 10: 自适应预取
    
    // 地址输入接口
    input logic [CHI_ADDR_WIDTH-1:0] access_addr, // 当前访问地址
    input logic access_valid, // 访问有效
    input logic access_is_write, // 是否为写操作
    
    // 预取请求输出
    output logic [CHI_ADDR_WIDTH-1:0] prefetch_addr, // 预取地址
    output logic prefetch_valid, // 预取有效
    output logic [2:0] prefetch_priority, // 预取优先级
    input logic prefetch_ready, // 预取就绪
    
    // 状态输出
    output logic [31:0] prefetch_count, // 预取计数
    output logic [31:0] prefetch_hit_count, // 预取命中计数
    output logic [31:0] prefetch_miss_count, // 预取未命中计数
    output logic [3:0] prefetch_frequency // 预取频率（每100次访问的预取次数）
);
    
    // 导入参数
    import llm_params::*;
    
    // 内部寄存器
    logic [CHI_ADDR_WIDTH-1:0] last_access_addr;
    logic [CHI_ADDR_WIDTH-1:0] stride_direction;
    logic [2:0] stride_counter;
    logic [31:0] access_count;
    logic [31:0] prefetch_count_q;
    logic [31:0] prefetch_hit_count_q;
    logic [31:0] prefetch_miss_count_q;
    logic [3:0] prefetch_frequency_q;
    
    // 预取状态机
    enum logic [2:0] {
        IDLE = 3'b000,
        DETECT_STRIDE = 3'b001,
        PREFETCH_SEQUENTIAL = 3'b010,
        PREFETCH_STRIDE = 3'b011,
        PREFETCH_ADAPTIVE = 3'b100
    } prefetch_state;
    
    // 计算缓存行地址
    function automatic [CHI_ADDR_WIDTH-1:0] get_cacheline_addr(input logic [CHI_ADDR_WIDTH-1:0] addr);
        return {addr[CHI_ADDR_WIDTH-1:OFFSET_WIDTH], {OFFSET_WIDTH{1'b0}}};
    endfunction
    
    // 计算下一个缓存行地址
    function automatic [CHI_ADDR_WIDTH-1:0] get_next_cacheline(input logic [CHI_ADDR_WIDTH-1:0] addr, input int offset);
        return addr + (offset * CACHELINE_SIZE);
    endfunction
    
    // 状态机逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prefetch_state <= IDLE;
            last_access_addr <= '0;
            stride_direction <= '0;
            stride_counter <= '0;
            access_count <= '0;
            prefetch_count_q <= '0;
            prefetch_hit_count_q <= '0;
            prefetch_miss_count_q <= '0;
            prefetch_frequency_q <= '0;
        end else begin
            // 统计访问次数
            if (access_valid) begin
                access_count <= access_count + 1;
            end
            
            // 计算预取频率
            if (access_count % 100 == 0 && access_count != 0) begin
                prefetch_frequency_q <= prefetch_count_q % 100;
                prefetch_count_q <= 0;
            end
            
            case (prefetch_state)
                IDLE:
                    if (access_valid && prefetch_en) begin
                        last_access_addr <= get_cacheline_addr(access_addr);
                        prefetch_state <= DETECT_STRIDE;
                    end
                
                DETECT_STRIDE:
                    if (access_valid) begin
                        logic [CHI_ADDR_WIDTH-1:0] current_cl_addr = get_cacheline_addr(access_addr);
                        logic [CHI_ADDR_WIDTH-1:0] expected_next_addr = get_next_cacheline(last_access_addr, 1);
                        logic [CHI_ADDR_WIDTH-1:0] expected_prev_addr = get_next_cacheline(last_access_addr, -1);
                        
                        if (current_cl_addr == expected_next_addr) begin
                            // 顺序访问，正向
                            stride_direction <= CACHELINE_SIZE;
                            stride_counter <= 1;
                            prefetch_state <= PREFETCH_SEQUENTIAL;
                        end else if (current_cl_addr == expected_prev_addr) begin
                            // 顺序访问，反向
                            stride_direction <= -CACHELINE_SIZE;
                            stride_counter <= 1;
                            prefetch_state <= PREFETCH_SEQUENTIAL;
                        end else if (current_cl_addr != last_access_addr) begin
                            // 可能是stride访问
                            stride_direction <= current_cl_addr - last_access_addr;
                            stride_counter <= 1;
                            prefetch_state <= PREFETCH_STRIDE;
                        end
                        
                        last_access_addr <= current_cl_addr;
                    end
                
                PREFETCH_SEQUENTIAL:
                    if (access_valid) begin
                        logic [CHI_ADDR_WIDTH-1:0] current_cl_addr = get_cacheline_addr(access_addr);
                        logic [CHI_ADDR_WIDTH-1:0] expected_addr = last_access_addr + stride_direction;
                        
                        if (current_cl_addr == expected_addr) begin
                            // 继续顺序访问
                            stride_counter <= stride_counter + 1;
                            if (stride_counter >= 2) begin
                                // 触发预取
                                prefetch_count_q <= prefetch_count_q + 1;
                            end
                        end else if (current_cl_addr != last_access_addr) begin
                            // 访问模式改变
                            prefetch_state <= DETECT_STRIDE;
                            stride_counter <= 0;
                        end
                        
                        last_access_addr <= current_cl_addr;
                    end
                
                PREFETCH_STRIDE:
                    if (access_valid) begin
                        logic [CHI_ADDR_WIDTH-1:0] current_cl_addr = get_cacheline_addr(access_addr);
                        logic [CHI_ADDR_WIDTH-1:0] expected_addr = last_access_addr + stride_direction;
                        
                        if (current_cl_addr == expected_addr) begin
                            // 继续stride访问
                            stride_counter <= stride_counter + 1;
                            if (stride_counter >= 2) begin
                                // 触发预取
                                prefetch_count_q <= prefetch_count_q + 1;
                            end
                        end else if (current_cl_addr != last_access_addr) begin
                            // 访问模式改变
                            prefetch_state <= DETECT_STRIDE;
                            stride_counter <= 0;
                        end
                        
                        last_access_addr <= current_cl_addr;
                    end
                
                PREFETCH_ADAPTIVE:
                    // 自适应预取策略
                    // 结合顺序和stride预取，根据命中率调整
                    if (access_valid) begin
                        last_access_addr <= get_cacheline_addr(access_addr);
                        // 简单实现：基于最近访问模式
                        if (prefetch_hit_count_q > prefetch_miss_count_q) begin
                            // 预取命中率高，增加预取深度
                            stride_counter <= (stride_counter < 7) ? stride_counter + 1 : 7;
                        end else begin
                            // 预取命中率低，减少预取深度
                            stride_counter <= (stride_counter > 1) ? stride_counter - 1 : 1;
                        end
                    end
            endcase
        end
    end
    
    // 预取请求生成
    always_comb begin
        prefetch_valid = 1'b0;
        prefetch_addr = '0;
        prefetch_priority = 3'b000; // 预取优先级较低
        
        if (prefetch_en && access_valid) begin
            case (prefetch_state)
                PREFETCH_SEQUENTIAL:
                    if (stride_counter >= 2) begin
                        // 顺序预取
                        for (int i = 1; i <= prefetch_depth; i++) begin
                            prefetch_valid = 1'b1;
                            prefetch_addr = get_next_cacheline(get_cacheline_addr(access_addr), i);
                        end
                    end
                
                PREFETCH_STRIDE:
                    if (stride_counter >= 2) begin
                        // Stride预取
                        prefetch_valid = 1'b1;
                        prefetch_addr = get_cacheline_addr(access_addr) + (stride_direction * prefetch_depth);
                    end
                
                PREFETCH_ADAPTIVE:
                    // 自适应预取
                    if (stride_counter >= 2) begin
                        prefetch_valid = 1'b1;
                        prefetch_addr = get_next_cacheline(get_cacheline_addr(access_addr), prefetch_depth);
                    end
            endcase
        end
    end
    
    // 输出赋值
    assign prefetch_count = prefetch_count_q;
    assign prefetch_hit_count = prefetch_hit_count_q;
    assign prefetch_miss_count = prefetch_miss_count_q;
    assign prefetch_frequency = prefetch_frequency_q;
    
endmodule