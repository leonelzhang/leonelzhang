import yfinance as yf
import pandas as pd
from typing import Dict, List, Optional, Union
from datetime import datetime, timedelta


class NasdaqStockFetcher:
    def __init__(self):
        pass

    def get_stock_info(self, symbol: str) -> Dict:
        try:
            stock = yf.Ticker(symbol)
            info = stock.info
            
            if not info:
                return {"error": f"无法获取股票 {symbol} 的信息"}
            
            result = {
                "symbol": symbol.upper(),
                "company_name": info.get("longName", "N/A"),
                "sector": info.get("sector", "N/A"),
                "industry": info.get("industry", "N/A"),
                "market_cap": info.get("marketCap", "N/A"),
                "current_price": info.get("currentPrice", "N/A"),
                "previous_close": info.get("previousClose", "N/A"),
                "open": info.get("open", "N/A"),
                "day_high": info.get("dayHigh", "N/A"),
                "day_low": info.get("dayLow", "N/A"),
                "volume": info.get("volume", "N/A"),
                "52_week_high": info.get("fiftyTwoWeekHigh", "N/A"),
                "52_week_low": info.get("fiftyTwoWeekLow", "N/A"),
                "pe_ratio": info.get("trailingPE", "N/A"),
                "dividend_yield": info.get("dividendYield", "N/A"),
                "beta": info.get("beta", "N/A"),
                "currency": info.get("currency", "USD"),
                "exchange": info.get("exchange", "N/A"),
                "website": info.get("website", "N/A"),
                "description": info.get("longBusinessSummary", "N/A")
            }
            
            return result
            
        except Exception as e:
            return {"error": f"获取股票信息时出错: {str(e)}"}

    def get_realtime_price(self, symbol: str) -> Dict:
        try:
            stock = yf.Ticker(symbol)
            hist = stock.history(period="1d", interval="1m")
            
            if hist.empty:
                return {"error": f"无法获取股票 {symbol} 的实时价格"}
            
            latest_price = hist['Close'].iloc[-1]
            currency = stock.info.get('currency', 'USD')
            last_update = hist.index[-1].strftime('%Y-%m-%d %H:%M:%S UTC')
            
            return {
                "symbol": symbol.upper(),
                "latest_price": round(float(latest_price), 2),
                "currency": currency,
                "last_update": last_update
            }
            
        except Exception as e:
            return {"error": f"获取实时价格时出错: {str(e)}"}

    def get_historical_data(self, symbol: str, period: str = "1y", interval: str = "1d") -> Union[pd.DataFrame, Dict]:
        try:
            stock = yf.Ticker(symbol)
            hist = stock.history(period=period, interval=interval)
            
            if hist.empty:
                return {"error": f"无法获取股票 {symbol} 的历史数据"}
            
            return hist
            
        except Exception as e:
            return {"error": f"获取历史数据时出错: {str(e)}"}

    def get_financial_data(self, symbol: str) -> Dict:
        try:
            stock = yf.Ticker(symbol)
            
            income_stmt = stock.income_stmt
            balance_sheet = stock.balance_sheet
            cash_flow = stock.cashflow
            
            result = {
                "symbol": symbol.upper(),
                "income_statement": income_stmt.to_dict() if income_stmt is not None else {},
                "balance_sheet": balance_sheet.to_dict() if balance_sheet is not None else {},
                "cash_flow": cash_flow.to_dict() if cash_flow is not None else {}
            }
            
            return result
            
        except Exception as e:
            return {"error": f"获取财务数据时出错: {str(e)}"}

    def get_stock_news(self, symbol: str, limit: int = 5) -> List[Dict]:
        try:
            stock = yf.Ticker(symbol)
            news = stock.news
            
            if not news:
                return []
            
            result = []
            for item in news[:limit]:
                result.append({
                    "title": item.get("title", "N/A"),
                    "link": item.get("link", "N/A"),
                    "published": item.get("providerPublishTime", "N/A"),
                    "publisher": item.get("publisher", "N/A")
                })
            
            return result
            
        except Exception as e:
            return [{"error": f"获取新闻时出错: {str(e)}"}]

    def get_multiple_stocks(self, symbols: List[str]) -> Dict:
        results = {}
        for symbol in symbols:
            results[symbol] = self.get_stock_info(symbol)
        return results

    def search_stocks(self, query: str) -> List[Dict]:
        try:
            import requests
            
            url = f"https://query1.finance.yahoo.com/v1/finance/search?q={query}"
            response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'})
            
            if response.status_code != 200:
                return [{"error": "搜索失败"}]
            
            data = response.json()
            quotes = data.get('quotes', [])
            
            results = []
            for quote in quotes[:10]:
                if 'symbol' in quote:
                    results.append({
                        "symbol": quote.get('symbol'),
                        "name": quote.get('longname', quote.get('shortname', 'N/A')),
                        "exchange": quote.get('exchange', 'N/A'),
                        "type": quote.get('quoteType', 'N/A')
                    })
            
            return results
            
        except Exception as e:
            return [{"error": f"搜索时出错: {str(e)}"}]

    def validate_symbol(self, symbol: str) -> bool:
        try:
            stock = yf.Ticker(symbol)
            info = stock.info
            return bool(info and info.get('symbol'))
        except:
            return False

    def get_stock_summary(self, symbol: str) -> Dict:
        try:
            stock = yf.Ticker(symbol)
            
            price_info = self.get_realtime_price(symbol)
            basic_info = self.get_stock_info(symbol)
            hist_5d = self.get_historical_data(symbol, period="5d", interval="1d")
            
            if isinstance(hist_5d, pd.DataFrame) and not hist_5d.empty:
                change_5d = ((hist_5d['Close'].iloc[-1] - hist_5d['Close'].iloc[0]) / hist_5d['Close'].iloc[0]) * 100
            else:
                change_5d = "N/A"
            
            result = {
                "symbol": symbol.upper(),
                "current_price": price_info.get("latest_price", "N/A"),
                "change_5d_percent": round(float(change_5d), 2) if isinstance(change_5d, float) else "N/A",
                "company_name": basic_info.get("company_name", "N/A"),
                "sector": basic_info.get("sector", "N/A"),
                "market_cap": basic_info.get("market_cap", "N/A"),
                "volume": basic_info.get("volume", "N/A"),
                "pe_ratio": basic_info.get("pe_ratio", "N/A"),
                "52_week_high": basic_info.get("52_week_high", "N/A"),
                "52_week_low": basic_info.get("52_week_low", "N/A")
            }
            
            return result
            
        except Exception as e:
            return {"error": f"获取股票摘要时出错: {str(e)}"}
