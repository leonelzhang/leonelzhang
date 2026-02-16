import yfinance as yf
import pandas as pd
import time


def get_adobe_5year_data_with_retry(max_retries=3, delay=30):
    print("=" * 70)
    print("Leaps - Adobe公司 (ADBE) 近五年股价信息")
    print("=" * 70)
    
    symbol = "ADBE"
    
    for attempt in range(max_retries):
        print(f"\n尝试 {attempt + 1}/{max_retries}...")
        
        try:
            print(f"正在创建 {symbol} 的Ticker对象...")
            stock = yf.Ticker(symbol)
            
            print(f"正在获取 {symbol} 近5年的历史数据...")
            
            hist = stock.history(period="5y", interval="1d")
            
            if hist.empty:
                print("警告: 获取到的数据为空")
                if attempt < max_retries - 1:
                    print(f"等待 {delay} 秒后重试...")
                    time.sleep(delay)
                    continue
                else:
                    return None
            
            print(f"✓ 成功获取 {len(hist)} 条数据")
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
            
            filename = f"{symbol}_5year_data.csv"
            hist.to_csv(filename)
            print(f"\n✓ 数据已保存至: {filename}")
            
            print("\n" + "=" * 70)
            print("分析完成！")
            print("=" * 70)
            
            return hist
            
        except Exception as e:
            error_msg = str(e)
            print(f"错误: {error_msg}")
            
            if "Rate limited" in error_msg or "Too Many Requests" in error_msg:
                if attempt < max_retries - 1:
                    print(f"遇到请求限制，等待 {delay} 秒后重试...")
                    time.sleep(delay)
                else:
                    print("\n已达到最大重试次数，请稍后再试。")
                    return None
            else:
                print(f"\n发生未知错误: {error_msg}")
                import traceback
                traceback.print_exc()
                return None
    
    return None


if __name__ == "__main__":
    print("注意: 由于API请求限制，可能需要等待一段时间...")
    result = get_adobe_5year_data_with_retry()
    
    if result is None:
        print("\n未能成功获取数据。建议:")
        print("1. 等待一段时间后再试")
        print("2. 检查网络连接")
        print("3. 使用其他数据源")
