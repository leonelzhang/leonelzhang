import tkinter as tk
from tkinter import ttk
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure
import pandas as pd
import numpy as np
from datetime import datetime, timedelta


def create_simple_chart(symbol="AAPL", period="1y"):
    root = tk.Tk()
    root.title(f"Leaps - {symbol}")
    root.geometry("1000x600")
    
    main_frame = ttk.Frame(root, padding="10")
    main_frame.pack(fill=tk.BOTH, expand=True)
    
    figure = Figure(figsize=(10, 8), dpi=100)
    ax = figure.add_subplot(211)
    macd_ax = figure.add_subplot(212)
    
    period_days = {
        '1mo': 30, '3mo': 90, '6mo': 180, '1y': 365,
        '2y': 730, '5y': 1825, '10y': 3650
    }
    
    days = period_days.get(period, 365)
    start_date = datetime.now() - timedelta(days=days)
    dates = pd.date_range(start=start_date, periods=int(days*0.7), freq='B')
    
    np.random.seed(hash(symbol) % 10000)
    
    base_prices = {
        'AAPL': 180.0, 'GOOGL': 140.0, 'MSFT': 380.0, 'AMZN': 170.0,
        'TSLA': 240.0, 'META': 480.0, 'NVDA': 880.0, 'NFLX': 550.0,
        'ADBE': 550.0, 'INTC': 45.0
    }
    
    initial_price = base_prices.get(symbol, 100.0)
    returns = np.random.normal(0.0005, 0.02, len(dates))
    
    prices = [initial_price]
    for ret in returns[1:]:
        prices.append(prices[-1] * (1 + ret))
    
    ax.plot(dates, prices, label=f'{symbol} 收盘价', linewidth=1.5, color='blue')
    
    ma20 = pd.Series(prices, index=dates).rolling(window=20).mean()
    ma50 = pd.Series(prices, index=dates).rolling(window=50).mean()
    
    if len(ma20.dropna()) > 0:
        ax.plot(ma20.index, ma20, label='MA20', linewidth=1, alpha=0.7, color='orange')
    if len(ma50.dropna()) > 0:
        ax.plot(ma50.index, ma50, label='MA50', linewidth=1, alpha=0.7, color='purple')
    
    signal_window = 20
    if len(prices) > signal_window:
        hist = pd.DataFrame({
            'Close': prices,
            'High': [p * 1.01 for p in prices],
            'Low': [p * 0.99 for p in prices]
        }, index=dates)
        
        rolling_high = hist['High'].rolling(window=signal_window).max()
        rolling_low = hist['Low'].rolling(window=signal_window).min()
        
        close_prices = pd.Series(prices, index=dates)
        ema12 = close_prices.ewm(span=12, adjust=False).mean()
        ema26 = close_prices.ewm(span=26, adjust=False).mean()
        macd_line = ema12 - ema26
        
        buy_signals = []
        sell_signals = []
        
        for i in range(signal_window, len(hist)):
            current_high = hist['High'].iloc[i]
            current_low = hist['Low'].iloc[i]
            current_macd = macd_line.iloc[i]
            
            prev_rolling_high = rolling_high.iloc[i-1]
            prev_rolling_low = rolling_low.iloc[i-1]
            
            if current_high > prev_rolling_high and current_macd > 0:
                buy_signals.append((hist.index[i], current_high))
            
            if current_low < prev_rolling_low and current_macd < 0:
                sell_signals.append((hist.index[i], current_low))
        
        if buy_signals:
            buy_dates, buy_prices = zip(*buy_signals)
            ax.scatter(buy_dates, buy_prices, marker='^', color='green', 
                      s=100, label='买入 (B)', zorder=5)
            
            for date, price in buy_signals:
                ax.annotate('B', xy=(date, price), xytext=(0, 10),
                          textcoords='offset points', fontsize=10, fontweight='bold',
                          color='green', ha='center', va='bottom')
        
        if sell_signals:
            sell_dates, sell_prices = zip(*sell_signals)
            ax.scatter(sell_dates, sell_prices, marker='v', color='red',
                      s=100, label='卖出 (S)', zorder=5)
            
            for date, price in sell_signals:
                ax.annotate('S', xy=(date, price), xytext=(0, -15),
                          textcoords='offset points', fontsize=10, fontweight='bold',
                          color='red', ha='center', va='top')
    
    ax.set_title(f'{symbol} 股票价格曲线 ({period})', fontsize=14, fontweight='bold')
    ax.set_xlabel('日期', fontsize=10)
    ax.set_ylabel('价格 ($)', fontsize=10)
    ax.grid(True, alpha=0.3)
    ax.legend()
    
    close_prices = pd.Series(prices, index=dates)
    
    ema12 = close_prices.ewm(span=12, adjust=False).mean()
    ema26 = close_prices.ewm(span=26, adjust=False).mean()
    
    macd_line = ema12 - ema26
    signal_line = macd_line.ewm(span=9, adjust=False).mean()
    histogram = macd_line - signal_line
    
    macd_ax.plot(macd_line.index, macd_line, label='MACD', 
                linewidth=1.5, color='blue')
    macd_ax.plot(signal_line.index, signal_line, label='信号线', 
                linewidth=1.5, color='orange')
    
    colors = ['green' if h > 0 else 'red' for h in histogram]
    macd_ax.bar(histogram.index, histogram, color=colors, alpha=0.6, label='柱状图')
    
    macd_ax.axhline(y=0, color='black', linestyle='--', linewidth=0.5, alpha=0.5)
    
    macd_ax.set_title('MACD指标', fontsize=12, fontweight='bold')
    macd_ax.set_xlabel('日期', fontsize=9)
    macd_ax.set_ylabel('MACD值', fontsize=9)
    macd_ax.grid(True, alpha=0.3)
    macd_ax.legend(loc='upper left', fontsize=8)
    
    macd_ax.tick_params(axis='x', labelsize=8)
    macd_ax.tick_params(axis='y', labelsize=8)
    
    figure.tight_layout()
    
    canvas = FigureCanvasTkAgg(figure, main_frame)
    canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True)
    
    info_frame = ttk.Frame(main_frame)
    info_frame.pack(fill=tk.X, pady=10)
    
    current_price = prices[-1]
    period_return = ((prices[-1] - prices[0]) / prices[0] * 100)
    
    ttk.Label(info_frame, text=f"当前价格: ${current_price:.2f}  |  "
                             f"期间涨幅: {period_return:.2f}%  |  "
                             f"数据点数: {len(prices)}",
             font=('Arial', 10, 'bold')).pack()
    
    root.mainloop()


if __name__ == "__main__":
    print("Leaps - 启动简单股票价格可视化...")
    print("支持的热门股票: AAPL, GOOGL, MSFT, AMZN, TSLA, META, NVDA, NFLX, ADBE, INTC")
    print("默认显示: AAPL (1年)")
    
    create_simple_chart("AAPL", "1y")
