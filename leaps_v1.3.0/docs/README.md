# Leaps - 纳斯达克股票信息获取模块

一个功能强大的Python模块，用于从纳斯达克等交易所获取股票信息。

## 功能特性

- 获取股票基本信息（公司名称、行业、市值等）
- 获取实时股票价格
- 获取历史价格数据
- 获取财务数据（损益表、资产负债表、现金流量表）
- 获取股票相关新闻
- 批量获取多只股票信息
- 搜索股票
- 验证股票代码
- 获取股票摘要

## 安装依赖

```bash
pip install -r requirements.txt
```

## 快速开始

### 基本使用

```python
from nasdaq_stock_fetcher import NasdaqStockFetcher

# 创建获取器实例
fetcher = NasdaqStockFetcher()

# 获取股票基本信息
info = fetcher.get_stock_info("AAPL")
print(info)

# 获取实时价格
price = fetcher.get_realtime_price("AAPL")
print(price)

# 获取历史数据
hist = fetcher.get_historical_data("AAPL", period="1y", interval="1d")
print(hist.head())
```

### 批量获取

```python
# 批量获取多只股票信息
results = fetcher.get_multiple_stocks(["AAPL", "GOOGL", "MSFT"])
for symbol, info in results.items():
    print(f"{symbol}: {info['company_name']} - {info['current_price']}")
```

### 搜索股票

```python
# 搜索股票
search_results = fetcher.search_stocks("Apple")
for result in search_results:
    print(f"{result['symbol']} - {result['name']}")
```

## API 文档

### NasdaqStockFetcher 类

#### 方法

- `get_stock_info(symbol: str) -> Dict`
  获取股票的详细信息
  
- `get_realtime_price(symbol: str) -> Dict`
  获取股票的实时价格
  
- `get_historical_data(symbol: str, period: str = "1y", interval: str = "1d") -> DataFrame`
  获取历史价格数据
  
- `get_financial_data(symbol: str) -> Dict`
  获取财务数据
  
- `get_stock_news(symbol: str, limit: int = 5) -> List[Dict]`
  获取股票相关新闻
  
- `get_multiple_stocks(symbols: List[str]) -> Dict`
  批量获取多只股票信息
  
- `search_stocks(query: str) -> List[Dict]`
  搜索股票
  
- `validate_symbol(symbol: str) -> bool`
  验证股票代码是否有效
  
- `get_stock_summary(symbol: str) -> Dict`
  获取股票摘要信息

## 参数说明

### period 参数（历史数据时间周期）
- `1d`: 1天
- `5d`: 5天
- `1mo`: 1个月
- `3mo`: 3个月
- `6mo`: 6个月
- `1y`: 1年
- `2y`: 2年
- `5y`: 5年
- `10y`: 10年
- `ytd`: 年初至今
- `max`: 最大可用时间

### interval 参数（数据间隔）
- `1m`: 1分钟
- `5m`: 5分钟
- `15m`: 15分钟
- `30m`: 30分钟
- `60m`: 60分钟
- `90m`: 90分钟
- `1h`: 1小时
- `1d`: 1天
- `5d`: 5天
- `1wk`: 1周
- `1mo`: 1个月
- `3mo`: 3个月

## 交互式示例

运行交互式示例程序：

```bash
python example_usage.py
```

## 运行测试

```bash
python test_nasdaq_fetcher.py
```

## 常用股票代码示例

- `AAPL`: 苹果公司
- `GOOGL`: 谷歌
- `MSFT`: 微软
- `AMZN`: 亚马逊
- `TSLA`: 特斯拉
- `META`: Meta (Facebook)
- `NVDA`: 英伟达
- `NFLX`: Netflix

## 注意事项

1. 本模块使用 yfinance 库，数据来源于 Yahoo Finance
2. 实时数据可能有延迟
3. 某些股票可能没有完整的数据
4. 建议在使用前验证股票代码的有效性

## 错误处理

所有方法都包含错误处理，当发生错误时会返回包含 "error" 键的字典：

```python
info = fetcher.get_stock_info("INVALID")
if "error" in info:
    print(f"错误: {info['error']}")
```

## 许可证

本项目仅供学习和研究使用。
