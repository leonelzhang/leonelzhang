import tkinter as tk
from tkinter import ttk, messagebox
from tkinter import filedialog
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import threading


class LeapsGUITest:
    def __init__(self, root):
        self.root = root
        self.root.title("Leaps (测试版)")
        self.root.geometry("1200x800")
        
        self.current_data = None
        self.current_symbol = None
        
        self.setup_ui()
        
    def setup_ui(self):
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        main_frame.columnconfigure(1, weight=1)
        main_frame.rowconfigure(1, weight=1)
        
        self.create_control_panel(main_frame)
        self.create_chart_panel(main_frame)
        self.create_info_panel(main_frame)
        
    def create_control_panel(self, parent):
        control_frame = ttk.LabelFrame(parent, text="控制面板", padding="10")
        control_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N), padx=(0, 10))
        
        ttk.Label(control_frame, text="股票代码:").grid(row=0, column=0, sticky=tk.W, pady=5)
        self.symbol_entry = ttk.Entry(control_frame, width=20)
        self.symbol_entry.grid(row=0, column=1, sticky=(tk.W, tk.E), pady=5)
        self.symbol_entry.insert(0, "AAPL")
        
        ttk.Label(control_frame, text="时间周期:").grid(row=1, column=0, sticky=tk.W, pady=5)
        self.period_var = tk.StringVar(value="1y")
        period_combo = ttk.Combobox(control_frame, textvariable=self.period_var, width=18)
        period_combo['values'] = ('1mo', '3mo', '6mo', '1y', '2y', '5y', '10y', 'ytd', 'max')
        period_combo.grid(row=1, column=1, sticky=(tk.W, tk.E), pady=5)
        
        ttk.Label(control_frame, text="数据间隔:").grid(row=2, column=0, sticky=tk.W, pady=5)
        self.interval_var = tk.StringVar(value="1d")
        interval_combo = ttk.Combobox(control_frame, textvariable=self.interval_var, width=18)
        interval_combo['values'] = ('1d', '5d', '1wk', '1mo', '3mo')
        interval_combo.grid(row=2, column=1, sticky=(tk.W, tk.E), pady=5)
        
        ttk.Label(control_frame, text="图表类型:").grid(row=3, column=0, sticky=tk.W, pady=5)
        self.chart_type_var = tk.StringVar(value="line")
        chart_type_combo = ttk.Combobox(control_frame, textvariable=self.chart_type_var, width=18)
        chart_type_combo['values'] = ('line', 'candlestick', 'volume')
        chart_type_combo.grid(row=3, column=1, sticky=(tk.W, tk.E), pady=5)
        
        ttk.Label(control_frame, text="显示选项:").grid(row=4, column=0, sticky=tk.W, pady=5)
        
        self.show_ma_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(control_frame, text="移动平均线", variable=self.show_ma_var).grid(row=5, column=0, columnspan=2, sticky=tk.W)
        
        self.show_volume_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(control_frame, text="成交量", variable=self.show_volume_var).grid(row=6, column=0, columnspan=2, sticky=tk.W)
        
        self.show_bollinger_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(control_frame, text="布林带", variable=self.show_bollinger_var).grid(row=7, column=0, columnspan=2, sticky=tk.W)
        
        self.show_signals_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(control_frame, text="买卖信号", variable=self.show_signals_var).grid(row=8, column=0, columnspan=2, sticky=tk.W)
        
        self.show_macd_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(control_frame, text="MACD指标", variable=self.show_macd_var).grid(row=9, column=0, columnspan=2, sticky=tk.W)
        
        ttk.Label(control_frame, text="信号周期:").grid(row=10, column=0, sticky=tk.W, pady=5)
        self.signal_period_var = tk.StringVar(value="1mo")
        signal_period_combo = ttk.Combobox(control_frame, textvariable=self.signal_period_var, width=18)
        signal_period_combo['values'] = ('1mo', '3mo', '6mo', '1y')
        signal_period_combo.grid(row=10, column=1, sticky=(tk.W, tk.E), pady=5)
        
        button_frame = ttk.Frame(control_frame)
        button_frame.grid(row=11, column=0, columnspan=2, pady=20)
        
        ttk.Button(button_frame, text="获取数据", command=self.fetch_data).grid(row=0, column=0, padx=5)
        ttk.Button(button_frame, text="刷新图表", command=self.refresh_chart).grid(row=0, column=1, padx=5)
        ttk.Button(button_frame, text="保存图表", command=self.save_chart).grid(row=0, column=2, padx=5)
        ttk.Button(button_frame, text="导出数据", command=self.export_data).grid(row=0, column=3, padx=5)
        
        ttk.Label(control_frame, text="常用股票:").grid(row=11, column=0, sticky=tk.W, pady=(20, 5))
        
        popular_stocks = ["AAPL", "GOOGL", "MSFT", "AMZN", "TSLA", "META", "NVDA", "NFLX", "ADBE", "INTC"]
        for i, stock in enumerate(popular_stocks):
            btn = ttk.Button(control_frame, text=stock, width=8,
                          command=lambda s=stock: self.quick_select_stock(s))
            btn.grid(row=12 + i//2, column=i%2, pady=2, padx=2)
        
    def create_chart_panel(self, parent):
        chart_frame = ttk.LabelFrame(parent, text="价格曲线", padding="10")
        chart_frame.grid(row=0, column=1, sticky=(tk.W, tk.E, tk.N, tk.S))
        chart_frame.columnconfigure(0, weight=1)
        chart_frame.rowconfigure(0, weight=1)
        
        self.figure = Figure(figsize=(10, 8), dpi=100)
        self.ax = self.figure.add_subplot(211)
        self.macd_ax = self.figure.add_subplot(212)
        
        self.canvas = FigureCanvasTkAgg(self.figure, chart_frame)
        self.canvas.get_tk_widget().grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        self.canvas.draw()
        
    def create_info_panel(self, parent):
        info_frame = ttk.LabelFrame(parent, text="股票信息", padding="10")
        info_frame.grid(row=1, column=0, columnspan=2, sticky=(tk.W, tk.E, tk.N, tk.S), pady=(10, 0))
        
        self.info_text = tk.Text(info_frame, height=8, width=80, wrap=tk.WORD)
        self.info_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        scrollbar = ttk.Scrollbar(info_frame, orient=tk.VERTICAL, command=self.info_text.yview)
        scrollbar.grid(row=0, column=1, sticky=(tk.N, tk.S))
        self.info_text['yscrollcommand'] = scrollbar.set
        
        info_frame.columnconfigure(0, weight=1)
        info_frame.rowconfigure(0, weight=1)
        
    def quick_select_stock(self, symbol):
        self.symbol_entry.delete(0, tk.END)
        self.symbol_entry.insert(0, symbol)
        
    def fetch_data(self):
        symbol = self.symbol_entry.get().strip().upper()
        
        if not symbol:
            messagebox.showerror("错误", "请输入股票代码")
            return
        
        period = self.period_var.get()
        interval = self.interval_var.get()
        
        self.root.config(cursor="watch")
        self.root.update()
        
        def fetch_thread():
            try:
                data = self.generate_sample_data(symbol, period)
                
                if data is None or data.empty:
                    self.root.after(0, lambda: self.show_error("未能获取到数据"))
                    return
                
                self.current_data = data
                self.current_symbol = symbol
                
                self.root.after(0, self.update_info_panel)
                self.root.after(0, self.refresh_chart)
                
            except Exception as e:
                self.root.after(0, lambda: self.show_error(f"获取数据时出错: {str(e)}"))
            finally:
                self.root.after(0, lambda: self.root.config(cursor=""))
        
        threading.Thread(target=fetch_thread, daemon=True).start()
        
    def generate_sample_data(self, symbol, period):
        period_days = {
            '1mo': 30,
            '3mo': 90,
            '6mo': 180,
            '1y': 365,
            '2y': 730,
            '5y': 1825,
            '10y': 3650,
            'ytd': 365,
            'max': 1825
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
        
        return hist
        
    def show_error(self, message):
        messagebox.showerror("错误", message)
        self.root.config(cursor="")
        
    def update_info_panel(self):
        if self.current_data is None:
            return
        
        symbol = self.current_symbol
        hist = self.current_data
        
        info_text = f"股票代码: {symbol}\n"
        info_text += f"数据时间范围: {hist.index[0].strftime('%Y-%m-%d')} 至 {hist.index[-1].strftime('%Y-%m-%d')}\n"
        info_text += f"数据点数: {len(hist)}\n\n"
        
        info_text += "价格统计:\n"
        info_text += f"  当前价格: ${hist['Close'].iloc[-1]:.2f}\n"
        info_text += f"  期间最高: ${hist['High'].max():.2f}\n"
        info_text += f"  期间最低: ${hist['Low'].min():.2f}\n"
        info_text += f"  期间涨幅: {((hist['Close'].iloc[-1] - hist['Close'].iloc[0]) / hist['Close'].iloc[0] * 100):.2f}%\n\n"
        
        info_text += "成交量统计:\n"
        info_text += f"  平均成交量: {hist['Volume'].mean():,.0f}\n"
        info_text += f"  最高成交量: {hist['Volume'].max():,.0f}\n\n"
        
        daily_returns = hist['Close'].pct_change()
        info_text += "波动率统计:\n"
        info_text += f"  平均日涨跌幅: {(daily_returns.mean() * 100):.3f}%\n"
        info_text += f"  最大单日涨幅: {(daily_returns.max() * 100):.2f}%\n"
        info_text += f"  最大单日跌幅: {(daily_returns.min() * 100):.2f}%\n"
        info_text += f"  年化波动率: {(daily_returns.std() * (252 ** 0.5) * 100):.2f}%\n"
        
        self.info_text.delete(1.0, tk.END)
        self.info_text.insert(tk.END, info_text)
        
    def refresh_chart(self):
        if self.current_data is None:
            return
        
        self.ax.clear()
        self.macd_ax.clear()
        
        hist = self.current_data
        chart_type = self.chart_type_var.get()
        
        if chart_type == "line":
            self.plot_line_chart(hist)
        elif chart_type == "candlestick":
            self.plot_candlestick_chart(hist)
        elif chart_type == "volume":
            self.plot_volume_chart(hist)
        
        if self.show_ma_var.get():
            self.plot_moving_averages(hist)
        
        if self.show_bollinger_var.get():
            self.plot_bollinger_bands(hist)
        
        if self.show_signals_var.get():
            self.plot_buy_sell_signals(hist)
        
        if self.show_macd_var.get():
            self.plot_macd(hist)
        
        self.ax.set_title(f"{self.current_symbol} 股票价格曲线", fontsize=14, fontweight='bold')
        self.ax.set_xlabel("日期", fontsize=10)
        self.ax.set_ylabel("价格 ($)", fontsize=10)
        self.ax.grid(True, alpha=0.3)
        
        self.figure.tight_layout()
        self.canvas.draw()
        
    def plot_line_chart(self, hist):
        self.ax.plot(hist.index, hist['Close'], label='收盘价', linewidth=1.5, color='blue')
        self.ax.legend()
        
    def plot_candlestick_chart(self, hist):
        from matplotlib.patches import Rectangle
        from matplotlib.lines import Line2D
        
        width = 0.6
        width2 = 0.1
        
        up = hist[hist['Close'] >= hist['Open']]
        down = hist[hist['Close'] < hist['Open']]
        
        for idx, row in up.iterrows():
            self.ax.add_patch(Rectangle((idx, row['Open']), width, row['Close'] - row['Open'],
                                       facecolor='green', edgecolor='green'))
            self.ax.add_line(Line2D([idx, idx], [row['Low'], row['High']],
                                   color='green', linewidth=0.5))
        
        for idx, row in down.iterrows():
            self.ax.add_patch(Rectangle((idx, row['Close']), width, row['Open'] - row['Close'],
                                       facecolor='red', edgecolor='red'))
            self.ax.add_line(Line2D([idx, idx], [row['Low'], row['High']],
                                   color='red', linewidth=0.5))
        
    def plot_volume_chart(self, hist):
        colors = ['green' if close >= open_price else 'red' 
                 for close, open_price in zip(hist['Close'], hist['Open'])]
        self.ax.bar(hist.index, hist['Volume'], color=colors, alpha=0.7)
        self.ax.set_ylabel("成交量", fontsize=10)
        
    def plot_moving_averages(self, hist):
        ma20 = hist['Close'].rolling(window=20).mean()
        ma50 = hist['Close'].rolling(window=50).mean()
        ma200 = hist['Close'].rolling(window=200).mean()
        
        if len(ma20.dropna()) > 0:
            self.ax.plot(ma20.index, ma20, label='MA20', linewidth=1, alpha=0.7, color='orange')
        if len(ma50.dropna()) > 0:
            self.ax.plot(ma50.index, ma50, label='MA50', linewidth=1, alpha=0.7, color='purple')
        if len(ma200.dropna()) > 0:
            self.ax.plot(ma200.index, ma200, label='MA200', linewidth=1, alpha=0.7, color='brown')
        
        self.ax.legend()
        
    def plot_bollinger_bands(self, hist):
        window = 20
        ma = hist['Close'].rolling(window=window).mean()
        std = hist['Close'].rolling(window=window).std()
        
        upper_band = ma + (std * 2)
        lower_band = ma - (std * 2)
        
        self.ax.fill_between(ma.index, upper_band, lower_band, alpha=0.2, color='gray', label='布林带')
        self.ax.legend()
        
    def plot_buy_sell_signals(self, hist):
        signal_period = self.signal_period_var.get()
        
        period_days = {
            '1mo': 20,
            '3mo': 60,
            '6mo': 120,
            '1y': 250
        }
        
        window = period_days.get(signal_period, 20)
        
        if len(hist) < window:
            return
        
        close_prices = hist['Close']
        ema12 = close_prices.ewm(span=12, adjust=False).mean()
        ema26 = close_prices.ewm(span=26, adjust=False).mean()
        macd_line = ema12 - ema26
        
        rolling_high = hist['High'].rolling(window=window).max()
        rolling_low = hist['Low'].rolling(window=window).min()
        
        buy_signals = []
        sell_signals = []
        
        for i in range(window, len(hist)):
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
            self.ax.scatter(buy_dates, buy_prices, marker='^', color='green', 
                          s=100, label='买入 (B)', zorder=5)
            
            for date, price in buy_signals:
                self.ax.annotate('B', xy=(date, price), xytext=(0, 10),
                              textcoords='offset points', fontsize=10, fontweight='bold',
                              color='green', ha='center', va='bottom')
        
        if sell_signals:
            sell_dates, sell_prices = zip(*sell_signals)
            self.ax.scatter(sell_dates, sell_prices, marker='v', color='red',
                          s=100, label='卖出 (S)', zorder=5)
            
            for date, price in sell_signals:
                self.ax.annotate('S', xy=(date, price), xytext=(0, -15),
                              textcoords='offset points', fontsize=10, fontweight='bold',
                              color='red', ha='center', va='top')
        
        if buy_signals or sell_signals:
            self.ax.legend()
        
    def plot_macd(self, hist):
        close_prices = hist['Close']
        
        ema12 = close_prices.ewm(span=12, adjust=False).mean()
        ema26 = close_prices.ewm(span=26, adjust=False).mean()
        
        macd_line = ema12 - ema26
        signal_line = macd_line.ewm(span=9, adjust=False).mean()
        histogram = macd_line - signal_line
        
        self.macd_ax.plot(macd_line.index, macd_line, label='MACD', 
                        linewidth=1.5, color='blue')
        self.macd_ax.plot(signal_line.index, signal_line, label='信号线', 
                        linewidth=1.5, color='orange')
        
        colors = ['green' if h > 0 else 'red' for h in histogram]
        self.macd_ax.bar(histogram.index, histogram, color=colors, alpha=0.6, label='柱状图')
        
        self.macd_ax.axhline(y=0, color='black', linestyle='--', linewidth=0.5, alpha=0.5)
        
        self.macd_ax.set_title('MACD指标', fontsize=12, fontweight='bold')
        self.macd_ax.set_xlabel('日期', fontsize=9)
        self.macd_ax.set_ylabel('MACD值', fontsize=9)
        self.macd_ax.grid(True, alpha=0.3)
        self.macd_ax.legend(loc='upper left', fontsize=8)
        
        self.macd_ax.tick_params(axis='x', labelsize=8)
        self.macd_ax.tick_params(axis='y', labelsize=8)
        
    def save_chart(self):
        if self.current_data is None:
            messagebox.showwarning("警告", "请先获取数据")
            return
        
        file_path = filedialog.asksaveasfilename(
            defaultextension=".png",
            filetypes=[("PNG files", "*.png"), ("PDF files", "*.pdf"), ("All files", "*.*")]
        )
        
        if file_path:
            self.figure.savefig(file_path, dpi=300, bbox_inches='tight')
            messagebox.showinfo("成功", f"图表已保存至: {file_path}")
            
    def export_data(self):
        if self.current_data is None:
            messagebox.showwarning("警告", "请先获取数据")
            return
        
        file_path = filedialog.asksaveasfilename(
            defaultextension=".csv",
            filetypes=[("CSV files", "*.csv"), ("Excel files", "*.xlsx"), ("All files", "*.*")]
        )
        
        if file_path:
            if file_path.endswith('.xlsx'):
                self.current_data.to_excel(file_path)
            else:
                self.current_data.to_csv(file_path)
            messagebox.showinfo("成功", f"数据已导出至: {file_path}")


def main():
    root = tk.Tk()
    app = LeapsGUITest(root)
    root.mainloop()


if __name__ == "__main__":
    main()
