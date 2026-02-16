from nasdaq_stock_fetcher import NasdaqStockFetcher


def main():
    fetcher = NasdaqStockFetcher()
    
    print("=" * 60)
    print("Leaps - 纳斯达克股票信息获取系统")
    print("=" * 60)
    
    while True:
        print("\n请选择操作:")
        print("1. 获取股票基本信息")
        print("2. 获取实时价格")
        print("3. 获取历史数据")
        print("4. 获取财务数据")
        print("5. 获取股票新闻")
        print("6. 批量获取股票信息")
        print("7. 搜索股票")
        print("8. 获取股票摘要")
        print("9. 验证股票代码")
        print("0. 退出")
        
        choice = input("\n请输入选项 (0-9): ").strip()
        
        if choice == "0":
            print("感谢使用，再见！")
            break
        
        elif choice == "1":
            symbol = input("请输入股票代码 (如 AAPL): ").strip().upper()
            info = fetcher.get_stock_info(symbol)
            print_stock_info(info)
        
        elif choice == "2":
            symbol = input("请输入股票代码 (如 AAPL): ").strip().upper()
            price = fetcher.get_realtime_price(symbol)
            print_realtime_price(price)
        
        elif choice == "3":
            symbol = input("请输入股票代码 (如 AAPL): ").strip().upper()
            period = input("请输入时间周期 (如 1mo, 3mo, 6mo, 1y, 5y, 默认1y): ").strip() or "1y"
            interval = input("请输入时间间隔 (如 1d, 1wk, 1mo, 默认1d): ").strip() or "1d"
            hist = fetcher.get_historical_data(symbol, period, interval)
            print_historical_data(hist)
        
        elif choice == "4":
            symbol = input("请输入股票代码 (如 AAPL): ").strip().upper()
            financial = fetcher.get_financial_data(symbol)
            print_financial_data(financial)
        
        elif choice == "5":
            symbol = input("请输入股票代码 (如 AAPL): ").strip().upper()
            limit = input("请输入新闻数量 (默认5): ").strip()
            limit = int(limit) if limit.isdigit() else 5
            news = fetcher.get_stock_news(symbol, limit)
            print_stock_news(news)
        
        elif choice == "6":
            symbols_input = input("请输入股票代码，用逗号分隔 (如 AAPL,GOOGL,MSFT): ").strip().upper()
            symbols = [s.strip() for s in symbols_input.split(",")]
            results = fetcher.get_multiple_stocks(symbols)
            print_multiple_stocks(results)
        
        elif choice == "7":
            query = input("请输入搜索关键词 (如 Apple): ").strip()
            results = fetcher.search_stocks(query)
            print_search_results(results)
        
        elif choice == "8":
            symbol = input("请输入股票代码 (如 AAPL): ").strip().upper()
            summary = fetcher.get_stock_summary(symbol)
            print_stock_summary(summary)
        
        elif choice == "9":
            symbol = input("请输入股票代码 (如 AAPL): ").strip().upper()
            is_valid = fetcher.validate_symbol(symbol)
            print(f"\n股票代码 '{symbol}' {'有效' if is_valid else '无效'}")
        
        else:
            print("\n无效的选项，请重新输入！")


def print_stock_info(info):
    print("\n" + "=" * 60)
    print("股票基本信息")
    print("=" * 60)
    
    if "error" in info:
        print(f"错误: {info['error']}")
        return
    
    print(f"股票代码: {info['symbol']}")
    print(f"公司名称: {info['company_name']}")
    print(f"行业: {info['industry']}")
    print(f"板块: {info['sector']}")
    print(f"交易所: {info['exchange']}")
    print(f"市值: {info['market_cap']}")
    print(f"当前价格: {info['current_price']} {info['currency']}")
    print(f"前收盘价: {info['previous_close']}")
    print(f"开盘价: {info['open']}")
    print(f"日内最高: {info['day_high']}")
    print(f"日内最低: {info['day_low']}")
    print(f"成交量: {info['volume']}")
    print(f"52周最高: {info['52_week_high']}")
    print(f"52周最低: {info['52_week_low']}")
    print(f"市盈率: {info['pe_ratio']}")
    print(f"股息收益率: {info['dividend_yield']}")
    print(f"Beta值: {info['beta']}")
    print(f"官网: {info['website']}")
    print(f"\n公司简介: {info['description']}")


def print_realtime_price(price):
    print("\n" + "=" * 60)
    print("实时价格")
    print("=" * 60)
    
    if "error" in price:
        print(f"错误: {price['error']}")
        return
    
    print(f"股票代码: {price['symbol']}")
    print(f"最新价格: {price['latest_price']} {price['currency']}")
    print(f"更新时间: {price['last_update']}")


def print_historical_data(hist):
    print("\n" + "=" * 60)
    print("历史数据")
    print("=" * 60)
    
    if isinstance(hist, dict) and "error" in hist:
        print(f"错误: {hist['error']}")
        return
    
    print(f"\n数据行数: {len(hist)}")
    print("\n最近10条记录:")
    print(hist.tail(10).to_string())


def print_financial_data(financial):
    print("\n" + "=" * 60)
    print("财务数据")
    print("=" * 60)
    
    if "error" in financial:
        print(f"错误: {financial['error']}")
        return
    
    print(f"\n股票代码: {financial['symbol']}")
    
    print("\n损益表 (Income Statement):")
    if financial['income_statement']:
        for key, value in list(financial['income_statement'].items())[:5]:
            print(f"  {key}: {value}")
    
    print("\n资产负债表 (Balance Sheet):")
    if financial['balance_sheet']:
        for key, value in list(financial['balance_sheet'].items())[:5]:
            print(f"  {key}: {value}")
    
    print("\n现金流量表 (Cash Flow):")
    if financial['cash_flow']:
        for key, value in list(financial['cash_flow'].items())[:5]:
            print(f"  {key}: {value}")


def print_stock_news(news):
    print("\n" + "=" * 60)
    print("股票新闻")
    print("=" * 60)
    
    if not news:
        print("没有找到新闻")
        return
    
    if "error" in news[0]:
        print(f"错误: {news[0]['error']}")
        return
    
    for i, item in enumerate(news, 1):
        print(f"\n{i}. {item['title']}")
        print(f"   发布者: {item['publisher']}")
        print(f"   链接: {item['link']}")


def print_multiple_stocks(results):
    print("\n" + "=" * 60)
    print("批量股票信息")
    print("=" * 60)
    
    for symbol, info in results.items():
        print(f"\n{symbol}:")
        if "error" in info:
            print(f"  错误: {info['error']}")
        else:
            print(f"  公司名称: {info['company_name']}")
            print(f"  当前价格: {info['current_price']} {info['currency']}")
            print(f"  市值: {info['market_cap']}")


def print_search_results(results):
    print("\n" + "=" * 60)
    print("搜索结果")
    print("=" * 60)
    
    if not results:
        print("没有找到结果")
        return
    
    if "error" in results[0]:
        print(f"错误: {results[0]['error']}")
        return
    
    for i, result in enumerate(results, 1):
        print(f"\n{i}. {result['symbol']} - {result['name']}")
        print(f"   交易所: {result['exchange']}")
        print(f"   类型: {result['type']}")


def print_stock_summary(summary):
    print("\n" + "=" * 60)
    print("股票摘要")
    print("=" * 60)
    
    if "error" in summary:
        print(f"错误: {summary['error']}")
        return
    
    print(f"股票代码: {summary['symbol']}")
    print(f"公司名称: {summary['company_name']}")
    print(f"当前价格: {summary['current_price']}")
    print(f"5日涨跌幅: {summary['change_5d_percent']}%")
    print(f"行业: {summary['sector']}")
    print(f"市值: {summary['market_cap']}")
    print(f"成交量: {summary['volume']}")
    print(f"市盈率: {summary['pe_ratio']}")
    print(f"52周最高: {summary['52_week_high']}")
    print(f"52周最低: {summary['52_week_low']}")


if __name__ == "__main__":
    main()
