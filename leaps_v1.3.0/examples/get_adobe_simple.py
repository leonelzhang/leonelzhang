import yfinance as yf
import pandas as pd
import time


def get_adobe_5year_data():
    print("=" * 70)
    print("Adobe公司 (ADBE) 近五年股价信息")
    print("=" * 70)
    
    symbol = "ADBE"
    
    print(f"\n正在创建 {symbol} 的Ticker对象...")
    stock = yf.Ticker(symbol)
    
    print(f"正在获取 {symbol} 近5年的历史数据...")
    time.sleep(3)
    
    try:
        hist = stock.history(period="5y", interval="1d")
        
        if hist.empty:
            print("错误: 未能获取到数据")
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
        print(f"错误: {str(e)}")
        import traceback
        traceback.print_exc()
        return None


if __name__ == "__main__":
    get_adobe_5year_data()
