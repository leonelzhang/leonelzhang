import pandas as pd
import numpy as np
from datetime import datetime, timedelta


def generate_sample_adobe_data():
    print("=" * 70)
    print("Leaps - Adobe公司 (ADBE) 近五年股价信息 (示例数据)")
    print("=" * 70)
    
    print("\n注意: 由于API请求限制，以下为模拟的示例数据")
    print("在实际使用中，请运行 get_adobe_retry.py 获取真实数据\n")
    
    symbol = "ADBE"
    
    start_date = datetime.now() - timedelta(days=5*365)
    dates = pd.date_range(start=start_date, periods=1258, freq='B')
    
    np.random.seed(42)
    
    initial_price = 250.0
    returns = np.random.normal(0.0005, 0.02, len(dates))
    
    prices = [initial_price]
    for ret in returns[1:]:
        prices.append(prices[-1] * (1 + ret))
    
    hist = pd.DataFrame({
        'Open': [p * (1 + np.random.uniform(-0.01, 0.01)) for p in prices],
        'High': [p * (1 + np.random.uniform(0, 0.02)) for p in prices],
        'Low': [p * (1 - np.random.uniform(0, 0.02)) for p in prices],
        'Close': prices,
        'Volume': [int(np.random.uniform(1000000, 5000000)) for _ in range(len(dates))]
    }, index=dates)
    
    hist = hist[hist['High'] >= hist['Low']]
    hist = hist[hist['High'] >= hist['Open']]
    hist = hist[hist['High'] >= hist['Close']]
    hist = hist[hist['Low'] <= hist['Open']]
    hist = hist[hist['Low'] <= hist['Close']]
    
    print(f"✓ 成功生成 {len(hist)} 条示例数据")
    print(f"数据时间范围: {hist.index[0].strftime('%Y-%m-%d')} 至 {hist.index[-1].strftime('%Y-%m-%d')}")
    
    print("\n" + "=" * 70)
    print("数据统计摘要")
    print("=" * 70)
    
    print(f"\n收盘价统计:")
    print(f"  5年最高价: ${hist['Close'].max():.2f}")
    print(f"  5年最低价: ${hist['Close'].min():.2f}")
    print(f"  当前价格: ${hist['Close'].iloc[-1]:.2f}")
    print(f"  5年前价格: ${hist['Close'].iloc[0]:.2f}")
    five_year_change = ((hist['Close'].iloc[-1] - hist['Close'].iloc[0]) / hist['Close'].iloc[0] * 100)
    print(f"  5年涨幅: {five_year_change:.2f}%")
    
    print(f"\n成交量统计:")
    print(f"  平均日成交量: {hist['Volume'].mean():,.0f}")
    print(f"  最高成交量: {hist['Volume'].max():,.0f}")
    print(f"  最低成交量: {hist['Volume'].min():,.0f}")
    
    print(f"\n波动率统计:")
    daily_returns = hist['Close'].pct_change()
    print(f"  平均日涨跌幅: {(daily_returns.mean() * 100):.3f}%")
    print(f"  最大单日涨幅: {(daily_returns.max() * 100):.2f}%")
    print(f"  最大单日跌幅: {(daily_returns.min() * 100):.2f}%")
    print(f"  年化波动率: {(daily_returns.std() * (252 ** 0.5) * 100):.2f}%")
    
    print("\n" + "=" * 70)
    print("年度表现")
    print("=" * 70)
    
    hist_copy = hist.copy()
    hist_copy['Year'] = hist_copy.index.year
    
    yearly_data = hist_copy.groupby('Year').agg({
        'Close': ['first', 'last', 'max', 'min'],
        'Volume': 'sum'
    })
    
    yearly_data.columns = ['年初价格', '年末价格', '最高价', '最低价', '总成交量']
    yearly_data['年度涨幅'] = ((yearly_data['年末价格'] - yearly_data['年初价格']) / yearly_data['年初价格'] * 100).round(2)
    
    print("\n" + yearly_data.to_string())
    
    print("\n" + "=" * 70)
    print("最近30个交易日数据")
    print("=" * 70)
    
    recent_30 = hist.tail(30)[['Open', 'High', 'Low', 'Close', 'Volume']]
    recent_30 = recent_30.round(2)
    print("\n" + recent_30.to_string())
    
    print("\n" + "=" * 70)
    print("数据保存")
    print("=" * 70)
    
    filename = f"{symbol}_5year_data_sample.csv"
    hist.to_csv(filename)
    print(f"\n✓ 示例数据已保存至: {filename}")
    
    print("\n" + "=" * 70)
    print("如何获取真实数据")
    print("=" * 70)
    
    print("\n要获取Adobe公司的真实股价数据，请:")
    print("1. 等待一段时间后运行: python get_adobe_retry.py")
    print("2. 或者使用以下代码:")
    print("""
from nasdaq_stock_fetcher import NasdaqStockFetcher

fetcher = NasdaqStockFetcher()
hist = fetcher.get_historical_data("ADBE", period="5y", interval="1d")
print(hist)
    """)
    
    print("\n" + "=" * 70)
    print("分析完成！")
    print("=" * 70)
    
    return hist


if __name__ == "__main__":
    generate_sample_adobe_data()
