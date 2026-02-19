// LLM测试文件
// 验证细化后的设计，包括chi_slv、cmd_ctrl、PCQ、data_ctrl、chi_mst、ecc_ctrl和prefetch_ctrl子模块
module llm_test;
    
    // 导入参数
    import llm_params::*;
    
    // 时钟和复位
    logic clk;
    logic rst_n;
    
    // 配置接口
    logic [1:0] replace_policy;
    logic ecc_en;
    logic prefetch_en;
    logic [2:0] prefetch_depth;
    logic [15:0] req_timeout;
    logic [1:0] chi_h_version;
    logic [PRIORITY_WIDTH-1:0] req_priority;
    logic [4:0] pcq_threshold;
    
    // 状态输出
    logic [2:0] pipeline_stage;
    logic [2:0] tag_ecc_error;
    logic [1:0] split_req_num;
    logic pcq_congestion;
    logic out_of_order_en;
    logic [7:0] snp_resp_latency;
    logic [31:0] error_report;
    logic [3:0] pending_req_count;
    
    // RN CHI-H协议接口
    logic [CHI_ADDR_WIDTH-1:0] rn_chi_req_addr;
    logic [CHI_DATA_WIDTH-1:0] rn_chi_req_data;
    logic [7:0] rn_chi_req_size;
    logic rn_chi_req_valid;
    logic rn_chi_req_snp;
    logic [31:0] rn_chi_req_pld;
    logic [PRIORITY_WIDTH-1:0] rn_chi_req_priority;
    logic rn_chi_req_ready;
    
    logic [CHI_DATA_WIDTH-1:0] rn_chi_resp_data;
    logic rn_chi_resp_valid;
    logic rn_chi_resp_error;
    logic [31:0] rn_chi_resp_pld;
    logic [PRIORITY_WIDTH-1:0] rn_chi_resp_priority;
    logic rn_chi_resp_ready;
    
    // SN CHI-H协议接口
    logic [CHI_ADDR_WIDTH-1:0] sn_chi_req_addr;
    logic [CHI_DATA_WIDTH-1:0] sn_chi_req_data;
    logic [7:0] sn_chi_req_size;
    logic sn_chi_req_valid;
    logic sn_chi_req_snp;
    logic [31:0] sn_chi_req_pld;
    logic [PRIORITY_WIDTH-1:0] sn_chi_req_priority;
    logic sn_chi_req_ready;
    
    logic [CHI_DATA_WIDTH-1:0] sn_chi_resp_data;
    logic sn_chi_resp_valid;
    logic sn_chi_resp_error;
    logic [31:0] sn_chi_resp_pld;
    logic sn_chi_resp_ready;
    
    // 测试计数器
    int test_count;
    int error_count;
    
    // 实例化LLM顶层模块
    llm_top dut (
        .clk(clk),
        .rst_n(rst_n),
        // 配置接口
        .replace_policy(replace_policy),
        .ecc_en(ecc_en),
        .prefetch_en(prefetch_en),
        .prefetch_depth(prefetch_depth),
        .req_timeout(req_timeout),
        .chi_h_version(chi_h_version),
        .req_priority(req_priority),
        .pcq_threshold(pcq_threshold),
        // 状态输出
        .pipeline_stage(pipeline_stage),
        .tag_ecc_error(tag_ecc_error),
        .split_req_num(split_req_num),
        .pcq_congestion(pcq_congestion),
        .out_of_order_en(out_of_order_en),
        .snp_resp_latency(snp_resp_latency),
        .error_report(error_report),
        .pending_req_count(pending_req_count),
        // RN接口
        .rn_chi_req_addr(rn_chi_req_addr),
        .rn_chi_req_data(rn_chi_req_data),
        .rn_chi_req_size(rn_chi_req_size),
        .rn_chi_req_valid(rn_chi_req_valid),
        .rn_chi_req_snp(rn_chi_req_snp),
        .rn_chi_req_pld(rn_chi_req_pld),
        .rn_chi_req_priority(rn_chi_req_priority),
        .rn_chi_req_ready(rn_chi_req_ready),
        .rn_chi_resp_data(rn_chi_resp_data),
        .rn_chi_resp_valid(rn_chi_resp_valid),
        .rn_chi_resp_error(rn_chi_resp_error),
        .rn_chi_resp_pld(rn_chi_resp_pld),
        .rn_chi_resp_priority(rn_chi_resp_priority),
        .rn_chi_resp_ready(rn_chi_resp_ready),
        // SN接口
        .sn_chi_req_addr(sn_chi_req_addr),
        .sn_chi_req_data(sn_chi_req_data),
        .sn_chi_req_size(sn_chi_req_size),
        .sn_chi_req_valid(sn_chi_req_valid),
        .sn_chi_req_snp(sn_chi_req_snp),
        .sn_chi_req_pld(sn_chi_req_pld),
        .sn_chi_req_priority(sn_chi_req_priority),
        .sn_chi_req_ready(sn_chi_req_ready),
        .sn_chi_resp_data(sn_chi_resp_data),
        .sn_chi_resp_valid(sn_chi_resp_valid),
        .sn_chi_resp_error(sn_chi_resp_error),
        .sn_chi_resp_pld(sn_chi_resp_pld),
        .sn_chi_resp_ready(sn_chi_resp_ready)
    );
    
    // 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // 复位生成
    initial begin
        rst_n = 0;
        #20 rst_n = 1;
    end
    
    // 测试场景
    initial begin
        // 初始化测试计数器
        test_count = 0;
        error_count = 0;
        
        // 初始化配置信号
        replace_policy = 2'b00; // LRU替换策略
        ecc_en = 1'b1; // 启用ECC
        prefetch_en = 1'b1; // 启用预取
        prefetch_depth = 3'b100; // 预取深度4
        req_timeout = 16'd1000; // 请求超时时间
        chi_h_version = 2'b10; // CHI-H v2.0
        req_priority = 3'b100; // 中等优先级
        pcq_threshold = 5'd24; // PCQ拥塞阈值
        
        // 初始化RN信号
        rn_chi_req_addr = 0;
        rn_chi_req_data = 0;
        rn_chi_req_size = 0;
        rn_chi_req_valid = 0;
        rn_chi_req_snp = 0;
        rn_chi_req_pld = 0;
        rn_chi_req_priority = 0;
        rn_chi_resp_ready = 0;
        
        // 初始化SN信号
        sn_chi_req_ready = 0;
        sn_chi_resp_data = 0;
        sn_chi_resp_valid = 0;
        sn_chi_resp_error = 0;
        sn_chi_resp_pld = 0;
        sn_chi_resp_ready = 0;
        
        // 等待复位完成
        @(posedge rst_n);
        #10;
        
        $display("=== LLM细化设计测试开始 ===");
        
        // 基本功能测试
        $display("=== 基本功能测试 ===");
        // 测试1: RN基本写入操作
        test_rn_write(64'h10000000, 64'hDEADBEEF);
        
        // 测试2: RN基本读取操作（缓存命中）
        test_rn_read(64'h10000000, 64'hDEADBEEF);
        
        // 测试3: RN SNP操作
        test_rn_snp(64'h10000000, 64'hDEADBEEF);
        
        // 高级功能测试
        $display("=== 高级功能测试 ===");
        // 测试4: RN数据拆分操作（256B访问）
        test_rn_split_access(64'h20000000, 256);
        
        // 测试5: RN缓存未命中情况
        test_rn_cache_miss(64'h30000000, 64'hCAFEBABE);
        
        // 测试6: 优先级调度测试
        test_priority_scheduling();
        
        // 测试7: 预取功能测试
        test_prefetch功能();
        
        // 测试8: ECC功能测试
        test_ecc功能();
        
        // SN接口测试
        $display("=== SN接口测试 ===");
        // 测试9: SN基本写入操作
        test_sn_write(64'h40000000, 64'h12345678);
        
        // 测试10: SN基本读取操作（缓存命中）
        test_sn_read(64'h40000000, 64'h12345678);
        
        // 测试11: SN SNP操作
        test_sn_snp(64'h40000000, 64'h12345678);
        
        // 测试12: SN数据拆分操作（256B访问）
        test_sn_split_access(64'h50000000, 256);
        
        // 测试13: SN缓存未命中情况
        test_sn_cache_miss(64'h60000000, 64'h87654321);
        
        // 结束测试
        #100;
        $display("=== LLM细化设计测试完成 ===");
        $display("测试总数: %d, 错误数: %d", test_count, error_count);
        
        if (error_count == 0) begin
            $display("✓ 所有测试通过!");
        end else begin
            $display("✗ 存在测试失败!");
        end
        
        $finish;
    end
    
    // 测试RN写入操作
    task test_rn_write(logic [CHI_ADDR_WIDTH-1:0] addr, logic [CHI_DATA_WIDTH-1:0] data);
        test_count++;
        $display("测试 %d: RN写入操作 - 地址: 0x%h, 数据: 0x%h", test_count, addr, data);
        
        // 发送写入请求
        rn_chi_req_addr = addr;
        rn_chi_req_data = data;
        rn_chi_req_size = 64; // 64B写入
        rn_chi_req_valid = 1;
        rn_chi_req_snp = 0;
        rn_chi_req_pld = {8'h02, 8'h40, 8'h00, 8'h00}; // 写入请求Pld
        rn_chi_resp_ready = 1;
        
        @(posedge clk);
        while (!rn_chi_req_ready) @(posedge clk);
        
        // 等待响应
        while (!rn_chi_resp_valid) @(posedge clk);
        
        // 检查响应
        if (rn_chi_resp_error) begin
            error_count++;
            $display("✗ RN写入操作错误!");
        end else begin
            $display("✓ RN写入操作成功, 响应Pld: 0x%h", rn_chi_resp_pld);
        end
        
        // 清理信号
        rn_chi_req_valid = 0;
        rn_chi_resp_ready = 0;
        #10;
    endtask
    
    // 测试RN读取操作
    task test_rn_read(logic [CHI_ADDR_WIDTH-1:0] addr, logic [CHI_DATA_WIDTH-1:0] expected_data);
        test_count++;
        $display("测试 %d: RN读取操作 - 地址: 0x%h, 期望数据: 0x%h", test_count, addr, expected_data);
        
        // 发送读取请求
        rn_chi_req_addr = addr;
        rn_chi_req_data = 0;
        rn_chi_req_size = 0; // 0表示读取
        rn_chi_req_valid = 1;
        rn_chi_req_snp = 0;
        rn_chi_req_pld = {8'h01, 8'h40, 8'h00, 8'h00}; // 读取请求Pld
        rn_chi_resp_ready = 1;
        
        @(posedge clk);
        while (!rn_chi_req_ready) @(posedge clk);
        
        // 等待响应
        while (!rn_chi_resp_valid) @(posedge clk);
        
        // 检查响应
        if (rn_chi_resp_error) begin
            error_count++;
            $display("✗ RN读取操作错误!");
        end else if (rn_chi_resp_data != expected_data) begin
            error_count++;
            $display("✗ RN读取数据不匹配: 期望 0x%h, 实际 0x%h", expected_data, rn_chi_resp_data);
        end else begin
            $display("✓ RN读取操作成功, 数据: 0x%h, 响应Pld: 0x%h", rn_chi_resp_data, rn_chi_resp_pld);
        end
        
        // 清理信号
        rn_chi_req_valid = 0;
        rn_chi_resp_ready = 0;
        #10;
    endtask
    
    // 测试RN SNP操作
    task test_rn_snp(logic [CHI_ADDR_WIDTH-1:0] addr, logic [CHI_DATA_WIDTH-1:0] expected_data);
        test_count++;
        $display("测试 %d: RN SNP操作 - 地址: 0x%h, 期望数据: 0x%h", test_count, addr, expected_data);
        
        // 发送SNP请求
        rn_chi_req_addr = addr;
        rn_chi_req_data = 0;
        rn_chi_req_size = 0;
        rn_chi_req_valid = 1;
        rn_chi_req_snp = 1;
        rn_chi_req_pld = {8'h03, 8'h40, 8'h00, 8'h00}; // SNP请求Pld
        rn_chi_resp_ready = 1;
        
        @(posedge clk);
        while (!rn_chi_req_ready) @(posedge clk);
        
        // 等待响应
        while (!rn_chi_resp_valid) @(posedge clk);
        
        // 检查响应
        if (rn_chi_resp_error) begin
            error_count++;
            $display("✗ RN SNP操作错误!");
        end else if (rn_chi_resp_data != expected_data) begin
            error_count++;
            $display("✗ RN SNP数据不匹配: 期望 0x%h, 实际 0x%h", expected_data, rn_chi_resp_data);
        end else begin
            $display("✓ RN SNP操作成功, 数据: 0x%h, 响应Pld: 0x%h", rn_chi_resp_data, rn_chi_resp_pld);
        end
        
        // 清理信号
        rn_chi_req_valid = 0;
        rn_chi_req_snp = 0;
        rn_chi_resp_ready = 0;
        #10;
    endtask
    
    // 测试RN数据拆分操作
    task test_rn_split_access(logic [CHI_ADDR_WIDTH-1:0] addr, int size);
        test_count++;
        $display("测试 %d: RN数据拆分操作 - 地址: 0x%h, 大小: %dB", test_count, addr, size);
        
        // 发送128B写入请求
        rn_chi_req_addr = addr;
        rn_chi_req_data = 64'h123456789ABCDEF0;
        rn_chi_req_size = size;
        rn_chi_req_valid = 1;
        rn_chi_req_snp = 0;
        rn_chi_req_pld = {8'h02, 8'h80, 8'h00, 8'h00}; // 128B写入请求Pld
        rn_chi_resp_ready = 1;
        
        @(posedge clk);
        while (!rn_chi_req_ready) @(posedge clk);
        
        // 等待响应
        int resp_count = 0;
        while (resp_count < 2) begin // 128B需要两个64B响应
            @(posedge clk);
            if (rn_chi_resp_valid) begin
                resp_count++;
                $display("  响应 %d: 数据 0x%h, Pld: 0x%h", resp_count, rn_chi_resp_data, rn_chi_resp_pld);
            end
        end
        
        // 检查响应
        if (rn_chi_resp_error) begin
            error_count++;
            $display("✗ RN数据拆分操作错误!");
        end else begin
            $display("✓ RN数据拆分操作成功");
        end
        
        // 清理信号
        rn_chi_req_valid = 0;
        rn_chi_resp_ready = 0;
        #10;
    endtask
    
    // 测试RN缓存未命中情况
    task test_rn_cache_miss(logic [CHI_ADDR_WIDTH-1:0] addr, logic [CHI_DATA_WIDTH-1:0] data);
        test_count++;
        $display("测试 %d: RN缓存未命中 - 地址: 0x%h, 数据: 0x%h", test_count, addr, data);
        
        // 模拟SN响应
        fork
            begin
                // 等待SN请求
                while (!sn_chi_req_valid) @(posedge clk);
                $display("  SN请求: 地址 0x%h, 大小 %dB", sn_chi_req_addr, sn_chi_req_size);
                
                // 发送SN响应
                sn_chi_req_ready = 1;
                @(posedge clk);
                sn_chi_req_ready = 0;
                
                sn_chi_resp_data = data;
                sn_chi_resp_valid = 1;
                sn_chi_resp_error = 0;
                sn_chi_resp_pld = {8'h11, 8'h00, 8'h00, 8'h00};
                @(posedge clk);
                sn_chi_resp_valid = 0;
            end
        join_none
        
        // 发送写入请求（新地址，应该缓存未命中）
        rn_chi_req_addr = addr;
        rn_chi_req_data = data;
        rn_chi_req_size = 64;
        rn_chi_req_valid = 1;
        rn_chi_req_snp = 0;
        rn_chi_req_pld = {8'h02, 8'h40, 8'h00, 8'h00}; // 写入请求Pld
        rn_chi_resp_ready = 1;
        
        @(posedge clk);
        while (!rn_chi_req_ready) @(posedge clk);
        
        // 等待响应
        while (!rn_chi_resp_valid) @(posedge clk);
        
        // 检查响应
        if (rn_chi_resp_error) begin
            error_count++;
            $display("✗ RN缓存未命中操作错误!");
        end else begin
            $display("✓ RN缓存未命中操作成功, 响应Pld: 0x%h", rn_chi_resp_pld);
        end
        
        // 验证数据是否正确写入
        test_rn_read(addr, data);
        
        // 清理信号
        rn_chi_req_valid = 0;
        rn_chi_resp_ready = 0;
        #10;
    endtask
    
    // 测试SN写入操作
    task test_sn_write(logic [CHI_ADDR_WIDTH-1:0] addr, logic [CHI_DATA_WIDTH-1:0] data);
        test_count++;
        $display("测试 %d: SN写入操作 - 地址: 0x%h, 数据: 0x%h", test_count, addr, data);
        
        // 发送SN写入请求
        rn_chi_req_addr = addr;
        rn_chi_req_data = data;
        rn_chi_req_size = 64; // 64B写入
        rn_chi_req_valid = 1;
        rn_chi_req_snp = 1;
        rn_chi_req_pld = {8'h02, 8'h40, 8'h00, 8'h00}; // 写入请求Pld
        rn_chi_resp_ready = 1;
        
        @(posedge clk);
        while (!rn_chi_req_ready) @(posedge clk);
        
        // 等待响应
        while (!rn_chi_resp_valid) @(posedge clk);
        
        // 检查响应
        if (rn_chi_resp_error) begin
            error_count++;
            $display("✗ SN写入操作错误!");
        end else begin
            $display("✓ SN写入操作成功, 响应Pld: 0x%h", rn_chi_resp_pld);
        end
        
        // 清理信号
        rn_chi_req_valid = 0;
        rn_chi_req_snp = 0;
        rn_chi_resp_ready = 0;
        #10;
    endtask
    
    // 测试SN读取操作
    task test_sn_read(logic [CHI_ADDR_WIDTH-1:0] addr, logic [CHI_DATA_WIDTH-1:0] expected_data);
        test_count++;
        $display("测试 %d: SN读取操作 - 地址: 0x%h, 期望数据: 0x%h", test_count, addr, expected_data);
        
        // 发送SN读取请求
        rn_chi_req_addr = addr;
        rn_chi_req_data = 0;
        rn_chi_req_size = 0; // 0表示读取
        rn_chi_req_valid = 1;
        rn_chi_req_snp = 1;
        rn_chi_req_pld = {8'h01, 8'h40, 8'h00, 8'h00}; // 读取请求Pld
        rn_chi_resp_ready = 1;
        
        @(posedge clk);
        while (!rn_chi_req_ready) @(posedge clk);
        
        // 等待响应
        while (!rn_chi_resp_valid) @(posedge clk);
        
        // 检查响应
        if (rn_chi_resp_error) begin
            error_count++;
            $display("✗ SN读取操作错误!");
        end else if (rn_chi_resp_data != expected_data) begin
            error_count++;
            $display("✗ SN读取数据不匹配: 期望 0x%h, 实际 0x%h", expected_data, rn_chi_resp_data);
        end else begin
            $display("✓ SN读取操作成功, 数据: 0x%h, 响应Pld: 0x%h", rn_chi_resp_data, rn_chi_resp_pld);
        end
        
        // 清理信号
        rn_chi_req_valid = 0;
        rn_chi_req_snp = 0;
        rn_chi_resp_ready = 0;
        #10;
    endtask
    
    // 测试SN SNP操作
    task test_sn_snp(logic [CHI_ADDR_WIDTH-1:0] addr, logic [CHI_DATA_WIDTH-1:0] expected_data);
        test_count++;
        $display("测试 %d: SN SNP操作 - 地址: 0x%h, 期望数据: 0x%h", test_count, addr, expected_data);
        
        // 发送SN SNP请求
        rn_chi_req_addr = addr;
        rn_chi_req_data = 0;
        rn_chi_req_size = 0;
        rn_chi_req_valid = 1;
        rn_chi_req_snp = 1;
        rn_chi_req_pld = {8'h03, 8'h40, 8'h00, 8'h00}; // SNP请求Pld
        rn_chi_resp_ready = 1;
        
        @(posedge clk);
        while (!rn_chi_req_ready) @(posedge clk);
        
        // 等待响应
        while (!rn_chi_resp_valid) @(posedge clk);
        
        // 检查响应
        if (rn_chi_resp_error) begin
            error_count++;
            $display("✗ SN SNP操作错误!");
        end else if (rn_chi_resp_data != expected_data) begin
            error_count++;
            $display("✗ SN SNP数据不匹配: 期望 0x%h, 实际 0x%h", expected_data, rn_chi_resp_data);
        end else begin
            $display("✓ SN SNP操作成功, 数据: 0x%h, 响应Pld: 0x%h", rn_chi_resp_data, rn_chi_resp_pld);
        end
        
        // 清理信号
        rn_chi_req_valid = 0;
        rn_chi_req_snp = 0;
        rn_chi_resp_ready = 0;
        #10;
    endtask
    
    // 测试SN数据拆分操作
    task test_sn_split_access(logic [CHI_ADDR_WIDTH-1:0] addr, int size);
        test_count++;
        $display("测试 %d: SN数据拆分操作 - 地址: 0x%h, 大小: %dB", test_count, addr, size);
        
        // 发送128B写入请求
        rn_chi_req_addr = addr;
        rn_chi_req_data = 64'h123456789ABCDEF0;
        rn_chi_req_size = size;
        rn_chi_req_valid = 1;
        rn_chi_req_snp = 1;
        rn_chi_req_pld = {8'h02, 8'h80, 8'h00, 8'h00}; // 128B写入请求Pld
        rn_chi_resp_ready = 1;
        
        @(posedge clk);
        while (!rn_chi_req_ready) @(posedge clk);
        
        // 等待响应
        int resp_count = 0;
        while (resp_count < 2) begin // 128B需要两个64B响应
            @(posedge clk);
            if (rn_chi_resp_valid) begin
                resp_count++;
                $display("  响应 %d: 数据 0x%h, Pld: 0x%h", resp_count, rn_chi_resp_data, rn_chi_resp_pld);
            end
        end
        
        // 检查响应
        if (rn_chi_resp_error) begin
            error_count++;
            $display("✗ SN数据拆分操作错误!");
        end else begin
            $display("✓ SN数据拆分操作成功");
        end
        
        // 清理信号
        rn_chi_req_valid = 0;
        rn_chi_req_snp = 0;
        rn_chi_resp_ready = 0;
        #10;
    endtask
    
    // 测试SN缓存未命中情况
    task test_sn_cache_miss(logic [CHI_ADDR_WIDTH-1:0] addr, logic [CHI_DATA_WIDTH-1:0] data);
        test_count++;
        $display("测试 %d: SN缓存未命中 - 地址: 0x%h, 数据: 0x%h", test_count, addr, data);
        
        // 模拟SN响应
        fork
            begin
                // 等待SN请求
                while (!sn_chi_req_valid) @(posedge clk);
                $display("  SN请求: 地址 0x%h, 大小 %dB", sn_chi_req_addr, sn_chi_req_size);
                
                // 发送SN响应
                sn_chi_req_ready = 1;
                @(posedge clk);
                sn_chi_req_ready = 0;
                
                sn_chi_resp_data = data;
                sn_chi_resp_valid = 1;
                sn_chi_resp_error = 0;
                sn_chi_resp_pld = {8'h11, 8'h00, 8'h00, 8'h00};
                @(posedge clk);
                sn_chi_resp_valid = 0;
            end
        join_none
        
        // 发送SN写入请求（新地址，应该缓存未命中）
        rn_chi_req_addr = addr;
        rn_chi_req_data = data;
        rn_chi_req_size = 64;
        rn_chi_req_valid = 1;
        rn_chi_req_snp = 1;
        rn_chi_req_pld = {8'h02, 8'h40, 8'h00, 8'h00}; // 写入请求Pld
        rn_chi_resp_ready = 1;
        
        @(posedge clk);
        while (!rn_chi_req_ready) @(posedge clk);
        
        // 等待响应
        while (!rn_chi_resp_valid) @(posedge clk);
        
        // 检查响应
        if (rn_chi_resp_error) begin
            error_count++;
            $display("✗ SN缓存未命中操作错误!");
        end else begin
            $display("✓ SN缓存未命中操作成功, 响应Pld: 0x%h", rn_chi_resp_pld);
        end
        
        // 验证数据是否正确写入
        test_sn_read(addr, data);
        
        // 清理信号
        rn_chi_req_valid = 0;
        rn_chi_req_snp = 0;
        rn_chi_resp_ready = 0;
        #10;
    endtask
    
endmodule