from nasdaq_stock_fetcher import NasdaqStockFetcher


def test_basic_functionality():
    fetcher = NasdaqStockFetcher()
    
    print("测试1: 获取苹果公司(AAPL)的基本信息...")
    info = fetcher.get_stock_info("AAPL")
    assert "error" not in info, "获取股票信息失败"
    assert info["symbol"] == "AAPL", "股票代码不匹配"
    print("✓ 测试1通过")
    
    print("\n测试2: 获取实时价格...")
    price = fetcher.get_realtime_price("AAPL")
    assert "error" not in price, "获取实时价格失败"
    assert "latest_price" in price, "缺少最新价格"
    print("✓ 测试2通过")
    
    print("\n测试3: 获取历史数据...")
    hist = fetcher.get_historical_data("AAPL", period="1mo", interval="1d")
    assert "error" not in hist, "获取历史数据失败"
    print(f"✓ 测试3通过 - 获取到 {len(hist)} 条历史数据")
    
    print("\n测试4: 验证股票代码...")
    is_valid = fetcher.validate_symbol("AAPL")
    assert is_valid == True, "股票代码验证失败"
    print("✓ 测试4通过")
    
    print("\n测试5: 获取股票摘要...")
    summary = fetcher.get_stock_summary("AAPL")
    assert "error" not in summary, "获取股票摘要失败"
    print("✓ 测试5通过")
    
    print("\n测试6: 批量获取股票信息...")
    results = fetcher.get_multiple_stocks(["AAPL", "GOOGL", "MSFT"])
    assert len(results) == 3, "批量获取失败"
    print("✓ 测试6通过")
    
    print("\n测试7: 搜索股票...")
    search_results = fetcher.search_stocks("Apple")
    assert len(search_results) > 0, "搜索失败"
    print(f"✓ 测试7通过 - 找到 {len(search_results)} 个结果")
    
    print("\n" + "=" * 60)
    print("所有测试通过！")
    print("=" * 60)


def test_error_handling():
    fetcher = NasdaqStockFetcher()
    
    print("\n测试错误处理...")
    
    print("\n测试无效股票代码...")
    info = fetcher.get_stock_info("INVALID123")
    assert "error" in info or info.get("symbol") == "INVALID123", "错误处理失败"
    print("✓ 无效股票代码测试通过")
    
    print("\n测试验证无效股票代码...")
    is_valid = fetcher.validate_symbol("INVALID123")
    assert is_valid == False, "无效股票代码验证失败"
    print("✓ 无效股票代码验证测试通过")


if __name__ == "__main__":
    print("=" * 60)
    print("Leaps - 纳斯达克股票获取模块测试")
    print("=" * 60)
    
    try:
        test_basic_functionality()
        test_error_handling()
    except Exception as e:
        print(f"\n测试失败: {str(e)}")
        import traceback
        traceback.print_exc()
