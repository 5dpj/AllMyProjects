# Quick Setup Guide - Gold Trading Robot

## 🚀 5-Minute Setup

### Step 1: Installation (2 minutes)
1. **Copy File**: Place `GoldTradingRobot.mq5` in `MetaTrader5/MQL5/Experts/`
2. **Compile**: Open MetaEditor (F4) → Open file → Compile (F7)
3. **Attach**: Drag EA to XAUUSD chart → Configure → Click OK

### Step 2: Essential Settings (2 minutes)

#### For Beginners (Conservative)
```
Risk Percent: 0.5%
Max Drawdown: 15%
Max Positions: 1
Enable Scalping: false
Enable Swing Trading: true
```

#### For Experienced (Moderate)
```
Risk Percent: 1.0%
Max Drawdown: 15%
Max Positions: 2
Enable Scalping: true
Enable Swing Trading: true
```

### Step 3: Enable Trading (1 minute)
1. **Auto Trading**: Press Ctrl+E or click AutoTrading button
2. **Check Symbol**: Ensure chart symbol matches "XAUUSD"
3. **Verify**: Look for smiley face in top-right corner

## ⚙️ Optimal Settings by Account Type

### Demo Account Testing
- Risk: 2% (for faster testing)
- Timeframe: M1 or H1
- Enable both strategies
- Monitor for 1 week minimum

### Live Small Account ($1K-$5K)
- Risk: 0.5%
- Max Positions: 1
- Conservative settings
- Swing trading only

### Live Medium Account ($5K-$25K)
- Risk: 1.0%
- Max Positions: 2
- Both strategies enabled
- Standard settings

### Live Large Account ($25K+)
- Risk: 1.0-1.5%
- Max Positions: 3
- Both strategies enabled
- Fine-tuned parameters

## 🔧 Critical Checklist

### Before Starting
- [ ] Demo tested for at least 1 week
- [ ] AutoTrading enabled in MT5
- [ ] Correct symbol selected (XAUUSD)
- [ ] Risk settings appropriate for account size
- [ ] Stable internet connection
- [ ] Sufficient account balance for margin

### Daily Monitoring
- [ ] Check open positions
- [ ] Monitor drawdown levels
- [ ] Review daily profit/loss
- [ ] Ensure EA is still running
- [ ] Check for any error messages

## 🚨 Safety Rules

1. **Never risk more than 2% per trade**
2. **Always start with demo accounts**
3. **Monitor maximum drawdown closely**
4. **Don't trade during major news events**
5. **Keep backup manual trading plan**

## 📊 Expected Performance

### Realistic Expectations
- **Monthly Return**: 5-15% (varies by market conditions)
- **Win Rate**: 45-65%
- **Maximum Drawdown**: 10-20%
- **Profit Factor**: 1.3-2.0

### Warning Signs
- Drawdown > 20%
- Win rate < 30%
- Consecutive losses > 10
- Unusual trading frequency

## 🔍 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| EA not trading | Enable AutoTrading (Ctrl+E) |
| Invalid symbol | Check symbol name matches broker |
| High drawdown | Reduce risk percentage |
| No positions | Wait for signal confirmation |
| Compilation error | Check MQL5 syntax and includes |

## 📞 Need Help?

1. **Check Logs**: MetaTrader Journal tab for error messages
2. **Review Documentation**: See full documentation file
3. **Test Settings**: Use Strategy Tester for backtesting
4. **Community Forums**: MQL5 community for technical support

---

**Remember**: Trading involves risk. Start small, test thoroughly, and never trade money you can't afford to lose!